# ModSync — пересылка DLL и модов с main-ПК на ПК друга по сети (Radmin VPN = обычная LAN).
# Один файл, только стандартная библиотека Python. GUI на tkinter.
#
# Как пользоваться:
#   1. На ОБОИХ ПК: python modsync.py   (нужен Python 3.8+; tkinter идет в комплекте)
#   2. На ПК ДРУГА:  роль Receiver, Target dir = папка игры/модов, Start.
#      Узнать Radmin-IP друга (вид 26.x.x.x) и вписать его у себя.
#   3. На СВОЕМ ПК:  роль Sender, Friend IP = IP друга, в поле папок строки вида
#      C:\build\Release =>            (DLL модлоадера -> корень папки друга)
#      C:\mods\mymod => mods/mymod     (мод -> подпапка у друга)
#      Start. Дальше: изменил DLL/моды -> друг получил за секунды.
#   4. Token должен совпадать на обоих концах (простой пароль от чужих).
#   5. В Radmin/файрволе разрешить порт (по умолчанию 48152 TCP).
#
# Важно: если у друга игра запущена и держит DLL, Windows не даст перезаписать файл.
# ModSync тогда сохранит его как <имя>.pending и напишет в лог — другу надо закрыть
# игру и нажать Sync now (или у тебя) еще раз.

import hashlib
import json
import os
import shutil
import socket
import struct
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext

MAGIC = b"MLSYNC1"
PROTO = 1
DEFAULT_PORT = 48152
CHUNK = 65536
CONFIG_FILE = "modsync.json"
IGNORE_DIRS = {".git", ".vs", "__pycache__", "Debug", "Release", "x64",
               ".history", "node_modules"}
IGNORE_EXTS = {".pdb", ".ilk", ".exp", ".lib", ".iobj", ".ipdb", ".tlog",
               ".lastbuildstate", ".user", ".aps", ".tmp", ".log"}


def log_default(msg):
    print(time.strftime("[%H:%M:%S] ") + msg)


# ---------------- сканер ----------------

def scan_dir(root, ignore_dirs=IGNORE_DIRS, ignore_exts=IGNORE_EXTS):
    """{relpath -> {'s': size, 'm': mtime, 'h': sha1}}"""
    out = {}
    root = os.path.abspath(root)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in ignore_dirs]
        for fn in filenames:
            if os.path.splitext(fn)[1].lower() in ignore_exts:
                continue
            full = os.path.join(dirpath, fn)
            try:
                st = os.stat(full)
            except OSError:
                continue
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            h = hashlib.sha1()
            try:
                with open(full, "rb") as f:
                    for chunk in iter(lambda: f.read(CHUNK), b""):
                        h.update(chunk)
            except OSError:
                continue
            out[rel] = {"s": st.st_size, "m": st.st_mtime, "h": h.hexdigest()}
    return out


# ---------------- протокол ----------------

def _send_msg(sock, obj):
    data = json.dumps(obj).encode("utf-8")
    sock.sendall(MAGIC + struct.pack(">I", len(data)) + data)


def _recvn(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("connection closed")
        buf += chunk
    return buf


def _recv_msg(sock):
    magic = _recvn(sock, len(MAGIC))
    if magic != MAGIC:
        raise ConnectionError("bad magic")
    (ln,) = struct.unpack(">I", _recvn(sock, 4))
    return json.loads(_recvn(sock, ln).decode("utf-8"))


def parse_pairs(text):
    """Строки 'локальная_папка => удаленная_подпапка' ('=>' можно опустить,
    тогда кладет в корень). Возвращает [(local, remote), ...]."""
    pairs = []
    for line in (text or "").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=>" in line:
            local, _, remote = line.partition("=>")
        else:
            local, remote = line, ""
        local = local.strip().strip('"')
        remote = remote.strip().strip("/").replace("\\", "/")
        if ".." in remote.split("/"):
            continue
        if local:
            pairs.append((local, remote))
    return pairs


def build_manifest(pairs):
    """Общий манифест по парам. Возвращает (manifest, sources).
    manifest: {remote_rel: {s,m,h}}, sources: {remote_rel: local_full}."""
    manifest, sources = {}, {}
    for local, remote in pairs:
        for rel, meta in scan_dir(local).items():
            r = f"{remote}/{rel}" if remote else rel
            manifest[r] = meta
            sources[r] = os.path.join(os.path.abspath(local),
                                      rel.replace("/", os.sep))
    return manifest, sources


def push_snapshot(host, port, token, pairs, delete_missing, logger):
    """Sender: отдать другу текущее состояние папок. Возвращает (ok, stats)."""
    manifest, sources = build_manifest(pairs)
    roots = sorted({p.split("/", 1)[0] if "/" in p else "" for p in manifest})
    stats = {"sent": 0, "bytes": 0, "skipped": 0, "locked": [], "deleted": 0}
    with socket.create_connection((host, port), timeout=15) as sock:
        sock.settimeout(60)
        _send_msg(sock, {"t": "hello", "proto": PROTO, "token": token})
        rep = _recv_msg(sock)
        if rep.get("t") != "welcome":
            return False, {"error": "auth fail (token не совпал?)"}
        files = [{"p": p, "s": v["s"], "m": v["m"], "h": v["h"]}
                 for p, v in manifest.items()]
        _send_msg(sock, {"t": "manifest", "files": files,
                         "delete_missing": delete_missing, "roots": roots})
        rep = _recv_msg(sock)
        if rep.get("t") != "need":
            return False, {"error": f"bad reply: {rep}"}
        stats["deleted"] = rep.get("deleted", 0)
        for rel in rep.get("paths", []):
            full = sources.get(rel)
            if not full or not os.path.isfile(full):
                stats["skipped"] += 1
                continue
            size = os.path.getsize(full)
            _send_msg(sock, {"t": "file", "p": rel, "s": size})
            with open(full, "rb") as f:
                while True:
                    chunk = f.read(CHUNK)
                    if not chunk:
                        break
                    sock.sendall(chunk)
                    stats["bytes"] += len(chunk)
            rep = _recv_msg(sock)
            if rep.get("t") == "file_ok":
                stats["sent"] += 1
            elif rep.get("t") == "file_locked":
                stats["locked"].append(rel)
            else:
                stats["skipped"] += 1
        _send_msg(sock, {"t": "done"})
    return True, stats


class Receiver:
    """TCP-сервер на ПК друга. Пишет файлы атомарно (tmp + replace)."""

    def __init__(self, port, token, target_dir, logger):
        self.port = port
        self.token = token
        self.target = os.path.abspath(target_dir)
        self.log = logger
        self._stop = threading.Event()
        self._thread = None

    def start(self):
        os.makedirs(self.target, exist_ok=True)
        self._thread = threading.Thread(target=self._serve, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        try:
            socket.create_connection(("127.0.0.1", self.port), timeout=2).close()
        except OSError:
            pass
        if self._thread:
            self._thread.join(timeout=5)

    def _serve(self):
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            srv.bind(("0.0.0.0", self.port))
        except OSError as e:
            self.log(f"! bind failed: {e} (порт занят?)")
            return
        srv.listen(4)
        srv.settimeout(1.0)
        self.log(f"Receiver слушает порт {self.port}, папка: {self.target}")
        while not self._stop.is_set():
            try:
                conn, addr = srv.accept()
            except socket.timeout:
                continue
            threading.Thread(target=self._handle, args=(conn, addr),
                             daemon=True).start()
        srv.close()

    def _handle(self, conn, addr):
        try:
            conn.settimeout(60)
            hello = _recv_msg(conn)
            if hello.get("t") != "hello" or hello.get("proto") != PROTO \
                    or hello.get("token") != self.token:
                _send_msg(conn, {"t": "auth_fail"})
                conn.close()
                self.log(f"! {addr[0]}: чужой token")
                return
            _send_msg(conn, {"t": "welcome"})
            man = _recv_msg(conn)
            assert man.get("t") == "manifest"
            deleted = 0
            if man.get("delete_missing"):
                wanted = {f["p"] for f in man["files"]}
                roots = set(man.get("roots", []))

                def _root_of(rel):
                    return rel.split("/", 1)[0] if "/" in rel else ""

                local = scan_dir(self.target)
                for rel in local:
                    if rel not in wanted and _root_of(rel) in roots:
                        try:
                            os.remove(os.path.join(
                                self.target, rel.replace("/", os.sep)))
                            deleted += 1
                        except OSError as e:
                            self.log(f"! не удалил {rel}: {e}")
            local = scan_dir(self.target)
            need = [f["p"] for f in man["files"]
                    if local.get(f["p"], {}).get("h") != f["h"]]
            _send_msg(conn, {"t": "need", "paths": need, "deleted": deleted})
            self.log(f"{addr[0]}: манифест, надо файлов: {len(need)}, удалено: {deleted}")
            for _ in need:
                head = _recv_msg(conn)
                assert head.get("t") == "file"
                rel, size = head["p"], head["s"]
                dest = os.path.join(self.target, rel.replace("/", os.sep))
                os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
                tmp = dest + ".part"
                left = size
                try:
                    with open(tmp, "wb") as f:
                        while left > 0:
                            chunk = conn.recv(min(CHUNK, left))
                            if not chunk:
                                raise ConnectionError("обрыв")
                            f.write(chunk)
                            left -= len(chunk)
                except OSError as e:
                    self.log(f"! не пишу {rel}: {e}")
                    _send_msg(conn, {"t": "file_locked", "p": rel})
                    continue
                try:
                    os.replace(tmp, dest)
                    try:
                        _send_msg(conn, {"t": "file_ok", "p": rel})
                    except OSError:
                        pass
                    self.log(f"+ {rel} ({size} б)")
                except PermissionError:
                    pend = dest + ".pending"
                    try:
                        if os.path.exists(pend):
                            os.remove(pend)
                        os.replace(tmp, pend)
                    except OSError:
                        pass
                    _send_msg(conn, {"t": "file_locked", "p": rel})
                    self.log(f"! {rel} занят (игра запущена?) -> сохранен как .pending")
            fin = _recv_msg(conn)
            assert fin.get("t") == "done"
            self.log("синхронизация завершена")
        except (ConnectionError, AssertionError, OSError) as e:
            self.log(f"! обрыв {addr[0]}: {e}")
        finally:
            conn.close()


# ---------------- GUI ----------------

class App:
    def __init__(self, root):
        self.root = root
        root.title("ModSync — DLL и моды другу")
        self.cfg = self._load_cfg()
        self.receiver = None
        self.watch_thread = None
        self.watch_stop = threading.Event()

        frm = tk.Frame(root, padx=10, pady=10)
        frm.pack(fill="both", expand=True)

        self.role = tk.StringVar(value=self.cfg.get("role", "sender"))
        tk.Label(frm, text="Роль этого ПК:").grid(row=0, column=0, sticky="w")
        tk.Radiobutton(frm, text="Sender (я делаю, отправляю)",
                       variable=self.role, value="sender").grid(row=0, column=1, sticky="w")
        tk.Radiobutton(frm, text="Receiver (я получаю)",
                       variable=self.role, value="receiver").grid(row=0, column=2, sticky="w")

        self.entries = {}
        row = 1
        for key, label, default in [
                ("host", "Friend IP (Radmin):", ""),
                ("port", "Порт:", str(DEFAULT_PORT)),
                ("token", "Token (пароль, одинаковый!):", "cossacks4"),
                ("target", "Target dir (куда кладу, receiver):", "")]:
            tk.Label(frm, text=label).grid(row=row, column=0, sticky="w")
            e = tk.Entry(frm, width=55)
            e.insert(0, self.cfg.get(key, default))
            e.grid(row=row, column=1, columnspan=2, sticky="we")
            self.entries[key] = e
            if key == "target":
                b = tk.Button(frm, text="...",
                              command=lambda: self._browse_entry("target"))
                b.grid(row=row, column=3)
            row += 1

        tk.Label(frm, text="Папки sender'а (каждая с новой строки):\nлокальная => удаленная\n(без => кладет в корень)").grid(
            row=row, column=0, sticky="nw")
        self.pairs_text = tk.Text(frm, width=60, height=5)
        pairs_init = self.cfg.get("pairs_text", "")
        if not pairs_init and self.cfg.get("watch"):
            pairs_init = self.cfg.get("watch") + " => \n"
        if not pairs_init:
            pairs_init = ("# пример:\n"
                          "# C:\\mods\\ModloaderForCossacks3 => \n"
                          "# C:\\mods\\mymaps => maps\n")
        self.pairs_text.insert("1.0", pairs_init)
        self.pairs_text.grid(row=row, column=1, columnspan=2, sticky="we")
        tk.Button(frm, text="+", command=self._browse_pair).grid(row=row, column=3)
        row += 1

        self.interval = tk.StringVar(value=self.cfg.get("interval", "3"))
        tk.Label(frm, text="Проверка изменений, сек:").grid(row=row, column=0, sticky="w")
        tk.Entry(frm, textvariable=self.interval, width=8).grid(row=row, column=1, sticky="w")
        self.del_var = tk.BooleanVar(value=self.cfg.get("delete_missing", False))
        tk.Checkbutton(frm, text="Удалять у друга лишние файлы",
                       variable=self.del_var).grid(row=row, column=2, sticky="w")
        row += 1

        btns = tk.Frame(frm)
        btns.grid(row=row, column=0, columnspan=4, pady=6)
        self.btn_start = tk.Button(btns, text="Start", width=12,
                                   command=self.start)
        self.btn_start.pack(side="left", padx=4)
        self.btn_stop = tk.Button(btns, text="Stop", width=12,
                                  command=self.stop, state="disabled")
        self.btn_stop.pack(side="left", padx=4)
        tk.Button(btns, text="Sync now", width=12,
                  command=self.sync_now).pack(side="left", padx=4)
        row += 1

        self.status = tk.Label(frm, text="остановлен", fg="gray")
        self.status.grid(row=row, column=0, columnspan=4, sticky="w")
        row += 1
        self.logw = scrolledtext.ScrolledText(frm, width=80, height=16,
                                              state="disabled")
        self.logw.grid(row=row, column=0, columnspan=4)
        self.log("ModSync готов. Выбери роль, заполни поля, жми Start.")

    def _load_cfg(self):
        try:
            with open(CONFIG_FILE, encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            return {}

    def _save_cfg(self):
        cfg = {"role": self.role.get(), "interval": self.interval.get(),
               "delete_missing": self.del_var.get(),
               "pairs_text": self.pairs_text.get("1.0", "end")}
        for k, e in self.entries.items():
            cfg[k] = e.get()
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(cfg, f, ensure_ascii=False, indent=1)
        except OSError:
            pass

    def _browse_entry(self, key):
        d = filedialog.askdirectory()
        if d:
            self.entries[key].delete(0, "end")
            self.entries[key].insert(0, d)

    def _browse_pair(self):
        d = filedialog.askdirectory(title="Локальная папка для синхронизации")
        if d:
            self.pairs_text.insert("end", d + " => \n")

    def log(self, msg):
        line = time.strftime("[%H:%M:%S] ") + msg + "\n"
        self.logw.configure(state="normal")
        self.logw.insert("end", line)
        self.logw.see("end")
        self.logw.configure(state="disabled")

    def _params(self):
        p = {k: e.get().strip() for k, e in self.entries.items()}
        try:
            p["port"] = int(p["port"])
        except ValueError:
            p["port"] = DEFAULT_PORT
        try:
            p["interval"] = max(1, int(self.interval.get()))
        except ValueError:
            p["interval"] = 3
        p["delete_missing"] = self.del_var.get()
        p["token"] = self.entries["token"].get()
        p["pairs"] = parse_pairs(self.pairs_text.get("1.0", "end"))
        return p

    def start(self):
        p = self._params()
        self._save_cfg()
        if self.role.get() == "receiver":
            if not p["target"]:
                messagebox.showerror("ModSync", "Укажи Target dir")
                return
            self.receiver = Receiver(p["port"], p["token"], p["target"], self.log)
            self.receiver.start()
            self.status.configure(text="receiver запущен", fg="green")
        else:
            if not p["host"] or not p["pairs"]:
                messagebox.showerror("ModSync", "Укажи Friend IP и хотя бы одну папку")
                return
            bad = [local for local, _ in p["pairs"] if not os.path.isdir(local)]
            if bad:
                messagebox.showerror("ModSync", "Папки не существуют:\n" + "\n".join(bad))
                return
            self.watch_stop.clear()
            self.watch_thread = threading.Thread(target=self._watch, args=(p,),
                                                 daemon=True)
            self.watch_thread.start()
            names = ", ".join(local for local, _ in p["pairs"])
            self.status.configure(text=f"sender: слежу за {names}", fg="green")
        self.btn_start.configure(state="disabled")
        self.btn_stop.configure(state="normal")

    def stop(self):
        self.watch_stop.set()
        if self.receiver:
            self.receiver.stop()
            self.receiver = None
        self.status.configure(text="остановлен", fg="gray")
        self.btn_start.configure(state="normal")
        self.btn_stop.configure(state="disabled")
        self.log("остановлен")

    def sync_now(self):
        p = self._params()
        self._save_cfg()
        if self.role.get() == "receiver":
            self.log("receiver: жду sender'а, мне жать нечего :)")
            return
        threading.Thread(target=self._push, args=(p,), daemon=True).start()

    def _push(self, p):
        try:
            ok, stats = push_snapshot(p["host"], p["port"], p["token"],
                                      p["pairs"], p["delete_missing"], self.log)
        except OSError as e:
            self.log(f"! не соединился с {p['host']}:{p['port']}: {e}")
            return
        if not ok:
            self.log(f"! {stats.get('error')}")
            return
        msg = f"готово: отправлено {stats['sent']}, {stats['bytes']} б"
        if stats["deleted"]:
            msg += f", удалено у друга: {stats['deleted']}"
        if stats["locked"]:
            msg += f" | ЗАНЯТЫ (игра запущена?): {', '.join(stats['locked'])}"
        self.log(msg)

    def _watch(self, p):
        self.log(f"слежу за {len(p['pairs'])} папками каждые {p['interval']} c")
        last = None
        while not self.watch_stop.is_set():
            try:
                manifest, _ = build_manifest(p["pairs"])
                sig = sorted((k, v["h"]) for k, v in manifest.items())
                if last is not None and sig != last:
                    self.log("изменения найдены, отправляю...")
                    self._push(p)
                last = sig
            except OSError as e:
                self.log(f"! скан: {e}")
            self.watch_stop.wait(p["interval"])


def main():
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
