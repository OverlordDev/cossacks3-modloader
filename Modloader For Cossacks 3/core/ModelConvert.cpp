#include "pch.h"
#include "ModelConvert.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <functional>
#include <vector>
#include <wincodec.h>

#pragma comment(lib, "windowscodecs.lib")

bool EncodeDds(const std::vector<uint8_t>& px, UINT w, UINT h, std::string* dds);

namespace
{
    constexpr float kGutter = 1.0f / 32; // поле клетки атласа (доля её стороны)

    // ---------- маленький JSON: хватает для glTF ----------

    struct Json
    {
        enum Type { Null, Bool, Number, String, Array, Object } type = Null;
        double number = 0;
        bool boolean = false;
        std::string string;
        std::vector<Json> array;
        std::vector<std::pair<std::string, Json>> object;

        const Json* Get(const char* key) const
        {
            for (const auto& [k, v] : object)
                if (k == key)
                    return &v;
            return nullptr;
        }
        const Json* At(size_t i) const { return type == Array && i < array.size() ? &array[i] : nullptr; }
        double Num(const char* key, double def) const
        {
            const Json* v = Get(key);
            return v && v->type == Number ? v->number : def;
        }
        int Int(const char* key, int def) const { return static_cast<int>(Num(key, def)); }
        std::string Str(const char* key) const
        {
            const Json* v = Get(key);
            return v && v->type == String ? v->string : std::string();
        }
    };

    class JsonParser
    {
    public:
        explicit JsonParser(const std::string& s) : m_s(s) {}

        bool Parse(Json* out)
        {
            if (!Value(out, 0))
                return false;
            Skip();
            return m_i == m_s.size() || m_s[m_i] == '\0' || m_s[m_i] == ' ';
        }

    private:
        const std::string& m_s;
        size_t m_i = 0;

        void Skip()
        {
            while (m_i < m_s.size() && (m_s[m_i] == ' ' || m_s[m_i] == '\t' || m_s[m_i] == '\n' || m_s[m_i] == '\r'))
                ++m_i;
        }

        bool Literal(const char* word)
        {
            size_t n = strlen(word);
            if (m_s.compare(m_i, n, word) != 0)
                return false;
            m_i += n;
            return true;
        }

        bool Str(std::string* out)
        {
            if (m_i >= m_s.size() || m_s[m_i] != '"')
                return false;
            ++m_i;
            while (m_i < m_s.size() && m_s[m_i] != '"')
            {
                char c = m_s[m_i++];
                if (c != '\\')
                {
                    *out += c;
                    continue;
                }
                if (m_i >= m_s.size())
                    return false;
                char e = m_s[m_i++];
                switch (e)
                {
                case 'n': *out += '\n'; break;
                case 't': *out += '\t'; break;
                case 'r': *out += '\r'; break;
                case 'b': *out += '\b'; break;
                case 'f': *out += '\f'; break;
                case 'u':
                {
                    if (m_i + 4 > m_s.size())
                        return false;
                    unsigned cp = strtoul(m_s.substr(m_i, 4).c_str(), nullptr, 16);
                    m_i += 4;
                    if (cp < 0x80)
                        *out += static_cast<char>(cp);
                    else if (cp < 0x800)
                    {
                        *out += static_cast<char>(0xC0 | (cp >> 6));
                        *out += static_cast<char>(0x80 | (cp & 0x3F));
                    }
                    else
                    {
                        *out += static_cast<char>(0xE0 | (cp >> 12));
                        *out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
                        *out += static_cast<char>(0x80 | (cp & 0x3F));
                    }
                    break;
                }
                default: *out += e; break; // \" \\ \/
                }
            }
            if (m_i >= m_s.size())
                return false;
            ++m_i;
            return true;
        }

        bool Value(Json* out, int depth)
        {
            if (depth > 64)
                return false;
            Skip();
            if (m_i >= m_s.size())
                return false;
            char c = m_s[m_i];
            if (c == '{')
            {
                out->type = Json::Object;
                ++m_i;
                Skip();
                if (m_i < m_s.size() && m_s[m_i] == '}')
                    return ++m_i, true;
                for (;;)
                {
                    Skip();
                    std::string key;
                    if (!Str(&key))
                        return false;
                    Skip();
                    if (m_i >= m_s.size() || m_s[m_i++] != ':')
                        return false;
                    Json v;
                    if (!Value(&v, depth + 1))
                        return false;
                    out->object.emplace_back(std::move(key), std::move(v));
                    Skip();
                    if (m_i < m_s.size() && m_s[m_i] == ',')
                    {
                        ++m_i;
                        continue;
                    }
                    return m_i < m_s.size() && m_s[m_i++] == '}';
                }
            }
            if (c == '[')
            {
                out->type = Json::Array;
                ++m_i;
                Skip();
                if (m_i < m_s.size() && m_s[m_i] == ']')
                    return ++m_i, true;
                for (;;)
                {
                    Json v;
                    if (!Value(&v, depth + 1))
                        return false;
                    out->array.push_back(std::move(v));
                    Skip();
                    if (m_i < m_s.size() && m_s[m_i] == ',')
                    {
                        ++m_i;
                        continue;
                    }
                    return m_i < m_s.size() && m_s[m_i++] == ']';
                }
            }
            if (c == '"')
            {
                out->type = Json::String;
                return Str(&out->string);
            }
            if (Literal("true"))
                return out->type = Json::Bool, out->boolean = true, true;
            if (Literal("false"))
                return out->type = Json::Bool, true;
            if (Literal("null"))
                return true;
            char* end = nullptr;
            out->number = strtod(m_s.c_str() + m_i, &end);
            if (end == m_s.c_str() + m_i)
                return false;
            out->type = Json::Number;
            m_i = end - m_s.c_str();
            return true;
        }
    };

    // ---------- матрицы glTF (по столбцам) ----------

    struct Mat { double m[16]; };

    Mat Identity()
    {
        Mat r{};
        r.m[0] = r.m[5] = r.m[10] = r.m[15] = 1;
        return r;
    }

    Mat Mul(const Mat& a, const Mat& b)
    {
        Mat r{};
        for (int c = 0; c < 4; ++c)
            for (int row = 0; row < 4; ++row)
                for (int k = 0; k < 4; ++k)
                    r.m[c * 4 + row] += a.m[k * 4 + row] * b.m[c * 4 + k];
        return r;
    }

    Mat NodeMatrix(const Json& node)
    {
        if (const Json* mj = node.Get("matrix"); mj && mj->type == Json::Array && mj->array.size() == 16)
        {
            Mat r;
            for (int i = 0; i < 16; ++i)
                r.m[i] = mj->array[i].number;
            return r;
        }
        double t[3] = { 0, 0, 0 }, q[4] = { 0, 0, 0, 1 }, s[3] = { 1, 1, 1 };
        auto read = [&](const char* key, double* dst, size_t n) {
            if (const Json* v = node.Get(key); v && v->type == Json::Array && v->array.size() == n)
                for (size_t i = 0; i < n; ++i)
                    dst[i] = v->array[i].number;
        };
        read("translation", t, 3);
        read("rotation", q, 4);
        read("scale", s, 3);
        double x = q[0], y = q[1], z = q[2], w = q[3];
        double r[9] = {
            1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w),     // столбец 0
            2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w),     // столбец 1
            2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y),     // столбец 2
        };
        Mat m = Identity();
        for (int c = 0; c < 3; ++c)
            for (int row = 0; row < 3; ++row)
                m.m[c * 4 + row] = r[c * 3 + row] * s[c];
        m.m[12] = t[0];
        m.m[13] = t[1];
        m.m[14] = t[2];
        return m;
    }

    double Det3(const Mat& a)
    {
        const double* m = a.m;
        return m[0] * (m[5] * m[10] - m[9] * m[6]) - m[4] * (m[1] * m[10] - m[9] * m[2]) + m[8] * (m[1] * m[6] - m[5] * m[2]);
    }

    // ---------- чтение данных glTF ----------

    struct Glb
    {
        Json json;
        const char* bin = nullptr;
        size_t binSize = 0;
    };

    int Components(const std::string& type)
    {
        return type == "SCALAR" ? 1 : type == "VEC2" ? 2 : type == "VEC3" ? 3 : type == "VEC4" ? 4 : 0;
    }

    int ComponentBytes(int ct)
    {
        return ct == 5126 || ct == 5125 ? 4 : ct == 5123 || ct == 5122 ? 2 : ct == 5121 || ct == 5120 ? 1 : 0;
    }

    // Любой accessor -> числа (float или целые, нормализованные — в 0..1).
    bool ReadAccessor(const Glb& g, int index, std::vector<double>* out, int* comps, std::string* error)
    {
        const Json* acc = g.json.Get("accessors") ? g.json.Get("accessors")->At(index) : nullptr;
        if (!acc)
            return *error = "accessor " + std::to_string(index) + " not found", false;
        int n = Components(acc->Str("type"));
        int ct = acc->Int("componentType", 0);
        int cb = ComponentBytes(ct);
        int count = acc->Int("count", 0);
        if (!n || !cb)
            return *error = "unsupported accessor type", false;
        if (acc->Get("sparse"))
            return *error = "sparse accessors are not supported (apply modifiers/shape keys before export)", false;
        const Json* bv = g.json.Get("bufferViews") ? g.json.Get("bufferViews")->At(acc->Int("bufferView", -1)) : nullptr;
        if (!bv)
            return *error = "accessor without bufferView", false;
        if (bv->Int("buffer", 0) != 0)
            return *error = "only one embedded buffer is supported: export as .glb", false;
        size_t stride = bv->Int("byteStride", 0) ? bv->Int("byteStride", 0) : static_cast<size_t>(n) * cb;
        size_t base = static_cast<size_t>(bv->Int("byteOffset", 0)) + acc->Int("byteOffset", 0);
        if (count > 0 && base + stride * (count - 1) + static_cast<size_t>(n) * cb > g.binSize)
            return *error = "accessor goes past the end of the binary chunk", false;
        bool normalized = acc->Get("normalized") && acc->Get("normalized")->boolean;
        out->resize(static_cast<size_t>(count) * n);
        for (int i = 0; i < count; ++i)
            for (int c = 0; c < n; ++c)
            {
                const char* p = g.bin + base + stride * i + static_cast<size_t>(c) * cb;
                double v = 0;
                switch (ct)
                {
                case 5126: { float f; memcpy(&f, p, 4); v = f; break; }
                case 5125: { uint32_t u; memcpy(&u, p, 4); v = u; break; }
                case 5123: { uint16_t u; memcpy(&u, p, 2); v = normalized ? u / 65535.0 : u; break; }
                case 5122: { int16_t u; memcpy(&u, p, 2); v = normalized ? std::max(u / 32767.0, -1.0) : u; break; }
                case 5121: { uint8_t u = static_cast<uint8_t>(*p); v = normalized ? u / 255.0 : u; break; }
                case 5120: { int8_t u = static_cast<int8_t>(*p); v = normalized ? std::max(u / 127.0, -1.0) : u; break; }
                }
                (*out)[static_cast<size_t>(i) * n + c] = v;
            }
        *comps = n;
        return true;
    }

    bool ParseGlb(const std::string& data, Glb* g, std::string* error)
    {
        auto u32 = [&](size_t at) { uint32_t v; memcpy(&v, data.data() + at, 4); return v; };
        if (data.size() < 20 || u32(0) != 0x46546C67) // "glTF"
            return *error = "not a .glb file (export glTF Binary from Blender)", false;
        if (u32(4) != 2)
            return *error = "only glTF 2.0 is supported", false;
        size_t at = 12;
        std::string json;
        while (at + 8 <= data.size())
        {
            uint32_t len = u32(at), type = u32(at + 4);
            if (at + 8 + len > data.size())
                return *error = "truncated .glb", false;
            if (type == 0x4E4F534A)
                json.assign(data.data() + at + 8, len);
            else if (type == 0x004E4942)
            {
                g->bin = data.data() + at + 8;
                g->binSize = len;
            }
            at += 8 + ((len + 3) & ~3u);
        }
        if (json.empty() || !JsonParser(json).Parse(&g->json))
            return *error = "cannot read the JSON part of the .glb", false;
        return true;
    }

    // Номер картинки (glTF images[]) базового цвета материала primitive, -1 — нет.
    int MaterialImageIndex(const Glb& g, const Json& prim)
    {
        const Json* mats = g.json.Get("materials");
        const Json* mat = mats ? mats->At(prim.Int("material", -1)) : nullptr;
        const Json* pbr = mat ? mat->Get("pbrMetallicRoughness") : nullptr;
        const Json* tex = pbr ? pbr->Get("baseColorTexture") : nullptr;
        const Json* textures = g.json.Get("textures");
        const Json* t = tex && textures ? textures->At(tex->Int("index", -1)) : nullptr;
        return t ? t->Int("source", -1) : -1;
    }

    std::string ImageBytes(const Glb& g, int index)
    {
        const Json* images = g.json.Get("images");
        const Json* img = images ? images->At(index) : nullptr;
        const Json* views = g.json.Get("bufferViews");
        const Json* bv = img && views ? views->At(img->Int("bufferView", -1)) : nullptr;
        if (!bv)
            return {};
        size_t off = bv->Int("byteOffset", 0), len = bv->Int("byteLength", 0);
        return off + len <= g.binSize ? std::string(g.bin + off, len) : std::string();
    }

    // Картинки всех материалов файла по порядку: одна раскладка атласа на весь .glb (у всех частей
    // здания одна текстура). slotOf[номер картинки glTF] = клетка атласа.
    void ImageSlots(const Glb& g, std::vector<int>* slotOf, std::vector<int>* images)
    {
        const Json* imgs = g.json.Get("images");
        slotOf->assign(imgs ? imgs->array.size() : 0, -1);
        if (const Json* meshes = g.json.Get("meshes"))
            for (const Json& m : meshes->array)
                if (const Json* prims = m.Get("primitives"))
                    for (const Json& p : prims->array)
                    {
                        int i = MaterialImageIndex(g, p);
                        if (i >= 0 && i < static_cast<int>(slotOf->size()) && (*slotOf)[i] < 0)
                        {
                            (*slotOf)[i] = static_cast<int>(images->size());
                            images->push_back(i);
                        }
                    }
    }

    // Картинка базового цвета материала primitive: байты PNG/JPEG из бинарной части.
    std::string MaterialImage(const Glb& g, const Json& prim)
    {
        const Json* mats = g.json.Get("materials");
        const Json* mat = mats ? mats->At(prim.Int("material", -1)) : nullptr;
        const Json* pbr = mat ? mat->Get("pbrMetallicRoughness") : nullptr;
        const Json* tex = pbr ? pbr->Get("baseColorTexture") : nullptr;
        const Json* textures = g.json.Get("textures");
        const Json* t = tex && textures ? textures->At(tex->Int("index", -1)) : nullptr;
        const Json* images = g.json.Get("images");
        const Json* img = t && images ? images->At(t->Int("source", -1)) : nullptr;
        const Json* views = g.json.Get("bufferViews");
        const Json* bv = img && views ? views->At(img->Int("bufferView", -1)) : nullptr;
        if (!bv)
            return {};
        size_t off = bv->Int("byteOffset", 0), len = bv->Int("byteLength", 0);
        if (off + len > g.binSize)
            return {};
        return std::string(g.bin + off, len);
    }

    // Часть здания по имени верхнего объекта сцены: stage1..stage4 (стадии стройки), death1/death2 (руины),
    // attach, stage1a..stage4a, death1a/death2a — пристройка (леса, лестница, обломки). Остальное — готовое здание (""). ".001" от Blender отбрасывается.
    std::string PartOf(std::string name)
    {
        for (char& c : name)
            c = static_cast<char>(tolower(static_cast<unsigned char>(c)));
        if (size_t dot = name.find('.'); dot != std::string::npos)
            name.erase(dot);
        static const char* const kParts[] = { "stage1", "stage2", "stage3", "stage4", "death1", "death2", "attach",
                                              "stage1a", "stage2a", "stage3a", "stage4a", "death1a", "death2a" };
        for (const char* p : kParts)
            if (name == p)
                return name;
        return {};
    }

    std::vector<int> SceneRoots(const Glb& g)
    {
        std::vector<int> roots;
        const Json* scenes = g.json.Get("scenes");
        const Json* scene = scenes ? scenes->At(g.json.Int("scene", 0)) : nullptr;
        if (scene && scene->Get("nodes"))
            for (const Json& r : scene->Get("nodes")->array)
                roots.push_back(static_cast<int>(r.number));
        return roots;
    }

    std::string NodeName(const Glb& g, int i)
    {
        const Json* nodes = g.json.Get("nodes");
        const Json* n = nodes ? nodes->At(i) : nullptr;
        return n ? n->Str("name") : std::string();
    }

    void Put32(std::string& s, uint32_t v) { s.append(reinterpret_cast<const char*>(&v), 4); }
    void PutF(std::string& s, float v) { s.append(reinterpret_cast<const char*>(&v), 4); }
}

std::vector<std::string> ModelConvert::GlbParts(const std::string& glb)
{
    Glb g;
    std::string error;
    std::vector<std::string> parts;
    if (!ParseGlb(glb, &g, &error))
        return parts;
    for (int r : SceneRoots(g))
    {
        std::string p = PartOf(NodeName(g, r));
        if (std::find(parts.begin(), parts.end(), p) == parts.end())
            parts.push_back(p);
    }
    return parts;
}

bool ModelConvert::GlbToOsm(const std::string& glb, const std::string& part, std::string* osm,
                            std::vector<std::string>* images, Stats* stats, std::string* error)
{
    Glb g;
    if (!ParseGlb(glb, &g, error))
        return false;

    std::vector<float> pos, uv; // игровые координаты и UV — по вершине
    std::vector<int> tris;      // уже в порядке игры
    std::vector<int> vslot;     // клетка атласа вершины (-1 — у материала нет картинки)
    int meshes = 0, outside = 0;
    std::vector<int> slotOf, imageList;
    ImageSlots(g, &slotOf, &imageList);

    const Json* nodes = g.json.Get("nodes");
    const Json* meshList = g.json.Get("meshes");
    std::function<bool(int, const Mat&, int)> visit = [&](int ni, const Mat& parent, int depth) -> bool {
        const Json* node = nodes ? nodes->At(ni) : nullptr;
        if (!node || depth > 64)
            return true;
        Mat world = Mul(parent, NodeMatrix(*node));
        const Json* mesh = meshList ? meshList->At(node->Int("mesh", -1)) : nullptr;
        if (mesh && mesh->Get("primitives"))
        {
            ++meshes;
            bool mirrored = Det3(world) < 0; // зеркальный масштаб меняет обход треугольников
            for (const Json& prim : mesh->Get("primitives")->array)
            {
                if (prim.Int("mode", 4) != 4)
                    continue; // линии и точки в модель не идут
                const Json* attrs = prim.Get("attributes");
                if (!attrs || !attrs->Get("POSITION"))
                    continue;
                std::vector<double> p, t, idx;
                int pc = 0, tc = 0, ic = 0;
                if (!ReadAccessor(g, attrs->Int("POSITION", -1), &p, &pc, error) || pc != 3)
                    return false;
                size_t n = p.size() / 3;
                if (attrs->Get("TEXCOORD_0") && (!ReadAccessor(g, attrs->Int("TEXCOORD_0", -1), &t, &tc, error) || tc != 2))
                    return false;
                if (prim.Get("indices") && !ReadAccessor(g, prim.Int("indices", -1), &idx, &ic, error))
                    return false;
                if (idx.empty())
                    for (size_t i = 0; i < n; ++i)
                        idx.push_back(static_cast<double>(i));

                int first = static_cast<int>(pos.size() / 3);
                int img = MaterialImageIndex(g, prim);
                int slot = img >= 0 && img < static_cast<int>(slotOf.size()) ? slotOf[img] : -1;
                vslot.insert(vslot.end(), n, slot);
                for (size_t i = 0; i < n; ++i)
                {
                    const double* m = world.m;
                    double x = p[i * 3], y = p[i * 3 + 1], z = p[i * 3 + 2];
                    double wx = m[0] * x + m[4] * y + m[8] * z + m[12];
                    double wy = m[1] * x + m[5] * y + m[9] * z + m[13];
                    double wz = m[2] * x + m[6] * y + m[10] * z + m[14];
                    // glTF (Y вверх, лицом +Z) -> игра (Z вверх, лицом -Y): (x, -z, y) — ровно оси Blender.
                    pos.push_back(static_cast<float>(wx));
                    pos.push_back(static_cast<float>(-wz));
                    pos.push_back(static_cast<float>(wy));
                    uv.push_back(t.empty() ? 0.f : static_cast<float>(t[i * 2]));
                    uv.push_back(t.empty() ? 0.f : static_cast<float>(1.0 - t[i * 2 + 1])); // v=0 внизу, как в игре
                }
                for (size_t i = 0; i + 2 < idx.size(); i += 3)
                {
                    int a = first + static_cast<int>(idx[i]), b = first + static_cast<int>(idx[i + 1]),
                        c = first + static_cast<int>(idx[i + 2]);
                    if (idx[i] >= n || idx[i + 1] >= n || idx[i + 2] >= n)
                        return *error = "triangle index out of range", false;
                    // glTF — против часовой, игра — по часовой (проверено по объёму моделей игры).
                    tris.insert(tris.end(), mirrored ? std::initializer_list<int>{ a, b, c } : std::initializer_list<int>{ a, c, b });
                }
            }
        }
        if (const Json* children = node->Get("children"))
            for (const Json& c : children->array)
                if (!visit(static_cast<int>(c.number), world, depth + 1))
                    return false;
        return true;
    };

    std::vector<int> roots = SceneRoots(g);
    if (roots.empty() && nodes) // без сцены: корни — узлы, которые ничьи не дети
    {
        std::vector<bool> child(nodes->array.size());
        for (const Json& n : nodes->array)
            if (const Json* c = n.Get("children"))
                for (const Json& k : c->array)
                    if (k.number >= 0 && k.number < child.size())
                        child[static_cast<size_t>(k.number)] = true;
        for (size_t i = 0; i < child.size(); ++i)
            if (!child[i])
                roots.push_back(static_cast<int>(i));
    }
    for (int root : roots)
        if (PartOf(NodeName(g, root)) == part && !visit(root, Identity(), 0))
            return false;

    // Несколько картинок — атлас: сетка cols x rows, UV каждой вершины — в клетку её картинки (с полем
    // kGutter по краям, чтобы мип-уровни не смешивали соседей). Повторяющиеся UV (тайлинг) в атласе
    // невозможны — зажимаем в 0..1.
    if (imageList.size() > 1)
    {
        int cols = static_cast<int>(std::ceil(std::sqrt(static_cast<double>(imageList.size()))));
        int rows = (static_cast<int>(imageList.size()) + cols - 1) / cols;
        for (size_t v = 0; v < vslot.size(); ++v)
        {
            int slot = std::max(0, vslot[v]);
            float& u = uv[v * 2];
            float& w = uv[v * 2 + 1];
            if (u < -0.001f || u > 1.001f || w < -0.001f || w > 1.001f)
                ++outside;
            u = std::clamp(u, 0.f, 1.f);
            w = std::clamp(w, 0.f, 1.f);
            int col = slot % cols, row = slot / cols; // row — сверху вниз по картинке
            u = (col + kGutter + u * (1 - 2 * kGutter)) / cols;
            w = (rows - 1 - row + kGutter + w * (1 - 2 * kGutter)) / rows; // v игры растёт вверх
        }
    }

    int nv = static_cast<int>(pos.size() / 3), nt = static_cast<int>(tris.size() / 3);
    if (nv == 0 || nt == 0)
        return *error = part.empty() ? "no triangle meshes in the .glb" : "part '" + part + "' has no triangle meshes", false;

    // .osm = MD2 (IDP2 v8) с float-вершинами и 32-битными индексами. UV — по одной на вершину.
    const int ofsSkins = 68, ofsUV = ofsSkins + 64, ofsTris = ofsUV + nv * 8, frameSize = 16 + 16 * nv,
              ofsFrames = ofsTris + nt * 24, ofsEnd = ofsFrames + frameSize;
    std::string out;
    out.reserve(ofsEnd);
    for (int v : { 844121161, 8, 256, 256, frameSize, 1, nv, nv, nt, 0, 1, ofsSkins, ofsUV, ofsTris, ofsFrames, ofsEnd, ofsEnd })
        Put32(out, static_cast<uint32_t>(v));
    std::string skin = "SkinBitMap";
    skin.resize(63, ':');
    out += skin;
    out += '\0';
    for (float f : uv)
        PutF(out, f);
    for (int i = 0; i < nt; ++i)
    {
        for (int k = 0; k < 3; ++k)
            Put32(out, tris[i * 3 + k]);
        for (int k = 0; k < 3; ++k)
            Put32(out, tris[i * 3 + k]); // UV-индекс = индекс вершины
    }
    out += std::string("FRAME 000......", 15) + '\0';
    for (int i = 0; i < nv; ++i)
    {
        PutF(out, pos[i * 3]);
        PutF(out, pos[i * 3 + 1]);
        PutF(out, pos[i * 3 + 2]);
        Put32(out, 1); // во всех моделях игры здесь 1
    }
    *osm = std::move(out);
    if (images)
    {
        images->clear();
        for (int i : imageList)
            images->push_back(ImageBytes(g, i));
    }
    if (stats)
        *stats = { nv, nt, meshes, static_cast<int>(imageList.size()), outside };
    return true;
}

namespace
{
    bool Decode(const std::string& image, std::vector<uint8_t>* out, UINT* ow, UINT* oh, std::string* error);
}

bool ModelConvert::ImageToDds(const std::vector<std::string>& images, bool playerColor, std::string* dds, std::string* error)
{
    if (images.empty())
        return *error = "no images", false;
    std::vector<std::vector<uint8_t>> decoded(images.size());
    std::vector<UINT> ws(images.size()), hs(images.size());
    for (size_t i = 0; i < images.size(); ++i)
    {
        if (!Decode(images[i], &decoded[i], &ws[i], &hs[i], error))
            return *error = "image " + std::to_string(i + 1) + ": " + *error, false;
        // Альфа = маска цвета игрока. Непрозрачная картинка (альфа везде 255) — значит маски нет.
        std::vector<uint8_t>& p = decoded[i];
        bool hasMask = false;
        for (size_t k = 3; k < p.size() && !hasMask; k += 4)
            hasMask = p[k] != 255;
        if (!playerColor || !hasMask)
            for (size_t k = 3; k < p.size(); k += 4)
                p[k] = 0;
    }

    if (images.size() == 1)
        return EncodeDds(decoded[0], ws[0], hs[0], dds);

    // Атлас: клетки одного размера (степень двойки по самой большой картинке, атлас не больше 4096);
    // картинка растягивается в клетку за вычетом поля, поле заполняется её краем.
    int cols = static_cast<int>(std::ceil(std::sqrt(static_cast<double>(images.size()))));
    int rows = (static_cast<int>(images.size()) + cols - 1) / cols;
    UINT biggest = 1;
    for (size_t i = 0; i < images.size(); ++i)
        biggest = std::max({ biggest, ws[i], hs[i] });
    UINT cell = 1;
    while (cell < biggest)
        cell *= 2;
    while (cell * static_cast<UINT>(std::max(cols, rows)) > 4096)
        cell /= 2;
    UINT w = cell * cols, h = cell * rows;
    std::vector<uint8_t> px(static_cast<size_t>(w) * h * 4, 0);
    for (size_t i = 0; i < images.size(); ++i)
    {
        UINT col = static_cast<UINT>(i % cols), row = static_cast<UINT>(i / cols);
        const std::vector<uint8_t>& src = decoded[i];
        for (UINT y = 0; y < cell; ++y)
            for (UINT x = 0; x < cell; ++x)
            {
                double lu = ((x + 0.5) / cell - kGutter) / (1 - 2 * kGutter);
                double lv = ((y + 0.5) / cell - kGutter) / (1 - 2 * kGutter);
                UINT sx = static_cast<UINT>(std::clamp(lu, 0.0, 1.0) * (ws[i] - 1) + 0.5);
                UINT sy = static_cast<UINT>(std::clamp(lv, 0.0, 1.0) * (hs[i] - 1) + 0.5);
                memcpy(&px[((static_cast<size_t>(row) * cell + y) * w + col * cell + x) * 4],
                       &src[(static_cast<size_t>(sy) * ws[i] + sx) * 4], 4);
            }
    }
    return EncodeDds(px, w, h, dds);
}

namespace
{
bool Decode(const std::string& image, std::vector<uint8_t>* out, UINT* ow, UINT* oh, std::string* error)
{
    HRESULT init = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    bool uninit = SUCCEEDED(init);
    std::vector<uint8_t> px;
    UINT w = 0, h = 0;
    {
        IWICImagingFactory* factory = nullptr;
        IWICStream* stream = nullptr;
        IWICBitmapDecoder* decoder = nullptr;
        IWICBitmapFrameDecode* frame = nullptr;
        IWICBitmapSource* bgra = nullptr;
        HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
        if (SUCCEEDED(hr)) hr = factory->CreateStream(&stream);
        if (SUCCEEDED(hr))
            hr = stream->InitializeFromMemory(reinterpret_cast<BYTE*>(const_cast<char*>(image.data())), static_cast<DWORD>(image.size()));
        if (SUCCEEDED(hr)) hr = factory->CreateDecoderFromStream(stream, nullptr, WICDecodeMetadataCacheOnDemand, &decoder);
        if (SUCCEEDED(hr)) hr = decoder->GetFrame(0, &frame);
        if (SUCCEEDED(hr)) hr = WICConvertBitmapSource(GUID_WICPixelFormat32bppBGRA, frame, &bgra);
        if (SUCCEEDED(hr)) hr = bgra->GetSize(&w, &h);
        if (SUCCEEDED(hr) && (w == 0 || h == 0 || w > 8192 || h > 8192))
            hr = E_INVALIDARG;
        if (SUCCEEDED(hr))
        {
            px.resize(static_cast<size_t>(w) * h * 4);
            hr = bgra->CopyPixels(nullptr, w * 4, static_cast<UINT>(px.size()), px.data());
        }
        for (IUnknown* u : std::initializer_list<IUnknown*>{ bgra, frame, decoder, stream, factory })
            if (u)
                u->Release();
        if (FAILED(hr))
        {
            if (uninit)
                CoUninitialize();
            char buf[80];
            sprintf_s(buf, "cannot decode the texture (HRESULT 0x%08lX)", static_cast<unsigned long>(hr));
            return *error = buf, false;
        }
    }
    if (uninit)
        CoUninitialize();
    *out = std::move(px);
    *ow = w;
    *oh = h;
    return true;
}
}

// Пиксели BGRA -> DDS DXT5 с мип-уровнями.
bool EncodeDds(const std::vector<uint8_t>& px, UINT w, UINT h, std::string* dds)
{
    // Мип-уровни: среднее по 2x2 до 1x1.
    std::vector<std::vector<uint8_t>> levels{ px };
    UINT lw = w, lh = h;
    while (lw > 1 || lh > 1)
    {
        UINT nw = std::max(1u, lw / 2), nh = std::max(1u, lh / 2);
        const std::vector<uint8_t>& src = levels.back();
        std::vector<uint8_t> dst(static_cast<size_t>(nw) * nh * 4);
        for (UINT y = 0; y < nh; ++y)
            for (UINT x = 0; x < nw; ++x)
                for (int c = 0; c < 4; ++c)
                {
                    UINT x0 = std::min(x * 2, lw - 1), x1 = std::min(x * 2 + 1, lw - 1);
                    UINT y0 = std::min(y * 2, lh - 1), y1 = std::min(y * 2 + 1, lh - 1);
                    unsigned sum = src[(y0 * lw + x0) * 4 + c] + src[(y0 * lw + x1) * 4 + c] +
                                   src[(y1 * lw + x0) * 4 + c] + src[(y1 * lw + x1) * 4 + c];
                    dst[(static_cast<size_t>(y) * nw + x) * 4 + c] = static_cast<uint8_t>((sum + 2) / 4);
                }
        levels.push_back(std::move(dst));
        lw = nw;
        lh = nh;
    }

    // DXT5, как все текстуры игры: несжатую DDS движок не рисует (кадр молча пропускается).
    std::vector<std::pair<UINT, UINT>> sizes;
    for (UINT sw = w, sh = h;; sw = std::max(1u, sw / 2), sh = std::max(1u, sh / 2))
    {
        sizes.push_back({ sw, sh });
        if (sw == 1 && sh == 1)
            break;
    }
    auto blocksOf = [](UINT sw, UINT sh) { return static_cast<uint32_t>(std::max(1u, (sw + 3) / 4) * std::max(1u, (sh + 3) / 4) * 16); };

    std::string out = "DDS ";
    uint32_t header[31] = {};
    header[0] = 124;                                                   // dwSize
    header[1] = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x80000;          // CAPS HEIGHT WIDTH PIXELFORMAT MIPMAPCOUNT LINEARSIZE
    header[2] = h;
    header[3] = w;
    header[4] = blocksOf(w, h);                                        // размер верхнего уровня
    header[6] = static_cast<uint32_t>(levels.size());
    header[18] = 32;                                                   // pixel format size
    header[19] = 0x4;                                                  // FOURCC
    header[20] = 0x35545844;                                           // "DXT5"
    header[26] = 0x1000 | 0x400000 | 0x8;                              // TEXTURE | MIPMAP | COMPLEX
    out.append(reinterpret_cast<const char*>(header), sizeof(header));

    for (size_t li = 0; li < levels.size(); ++li)
    {
        const std::vector<uint8_t>& img = levels[li];
        UINT sw = sizes[li].first, sh = sizes[li].second;
        for (UINT by = 0; by < std::max(1u, (sh + 3) / 4); ++by)
            for (UINT bx = 0; bx < std::max(1u, (sw + 3) / 4); ++bx)
            {
                uint8_t px4[16][4]; // BGRA, края повторяются
                for (int i = 0; i < 16; ++i)
                {
                    UINT x = std::min(bx * 4 + i % 4, sw - 1), y = std::min(by * 4 + i / 4, sh - 1);
                    memcpy(px4[i], &img[(static_cast<size_t>(y) * sw + x) * 4], 4);
                }
                // альфа: 8 уровней между max и min
                uint8_t a0 = 0, a1 = 255;
                for (auto& p : px4) { a0 = std::max(a0, p[3]); a1 = std::min(a1, p[3]); }
                uint64_t abits = 0;
                if (a0 != a1)
                    for (int i = 0; i < 16; ++i)
                    {
                        int best = 0, bestErr = 1 << 30;
                        for (int k = 0; k < 8; ++k)
                        {
                            int v = k == 0 ? a0 : k == 1 ? a1 : ((8 - k) * a0 + (k - 1) * a1) / 7;
                            int e = std::abs(v - px4[i][3]);
                            if (e < bestErr) { bestErr = e; best = k; }
                        }
                        abits |= static_cast<uint64_t>(best) << (3 * i);
                    }
                out += static_cast<char>(a0);
                out += static_cast<char>(a1);
                for (int k = 0; k < 6; ++k)
                    out += static_cast<char>((abits >> (8 * k)) & 0xFF);
                // цвет: концы — min/max по каналам, 4 цвета
                int lo[3] = { 255, 255, 255 }, hi[3] = { 0, 0, 0 };
                for (auto& p : px4)
                    for (int c = 0; c < 3; ++c) { lo[c] = std::min<int>(lo[c], p[c]); hi[c] = std::max<int>(hi[c], p[c]); }
                auto to565 = [](const int bgr[3]) { return static_cast<uint16_t>(((bgr[2] >> 3) << 11) | ((bgr[1] >> 2) << 5) | (bgr[0] >> 3)); };
                uint16_t c0 = to565(hi), c1 = to565(lo);
                if (c0 < c1) std::swap(c0, c1);
                auto from565 = [](uint16_t c, int bgr[3]) {
                    bgr[2] = ((c >> 11) & 31) * 255 / 31; bgr[1] = ((c >> 5) & 63) * 255 / 63; bgr[0] = (c & 31) * 255 / 31;
                };
                int pal[4][3];
                from565(c0, pal[0]);
                from565(c1, pal[1]);
                for (int c = 0; c < 3; ++c)
                {
                    pal[2][c] = (2 * pal[0][c] + pal[1][c]) / 3;
                    pal[3][c] = (pal[0][c] + 2 * pal[1][c]) / 3;
                }
                uint32_t cbits = 0;
                if (c0 != c1)
                    for (int i = 0; i < 16; ++i)
                    {
                        int best = 0, bestErr = 1 << 30;
                        for (int k = 0; k < 4; ++k)
                        {
                            int e = 0;
                            for (int c = 0; c < 3; ++c)
                                e += (pal[k][c] - px4[i][c]) * (pal[k][c] - px4[i][c]);
                            if (e < bestErr) { bestErr = e; best = k; }
                        }
                        cbits |= static_cast<uint32_t>(best) << (2 * i);
                    }
                out.append(reinterpret_cast<const char*>(&c0), 2);
                out.append(reinterpret_cast<const char*>(&c1), 2);
                out.append(reinterpret_cast<const char*>(&cbits), 4);
            }
    }
    *dds = std::move(out);
    return true;
}
