// Стенд для ModelDecimate: прогоняет все юнитские .oss игры, проверяет результат и меряет отклонение.
// Сборка и запуск: tools/decimate_test/run.bat "<папка игры>" [доли через пробел]
//
// Проверяется не «похоже ли на юнита» (это только глазами, в игре), а то, что можно проверить числами:
//  - файл разбирается тем же парсером, индексы в диапазоне, нет вырожденных треугольников;
//  - кадры костей байт-в-байт те же;
//  - отклонение: расстояние от каждой ИСХОДНОЙ вершины до упрощённой поверхности, в позе привязки и
//    на кадрах анимации (вершина везёт свои кости), в долях диагонали модели.
#include "../../Modloader For Cossacks 3/core/ModelDecimate.cpp"

#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace fs = std::filesystem;

static double PointTri(const V3& p, const V3& a, const V3& b, const V3& c)
{
    // Ближайшая точка на треугольнике (Ericson, Real-Time Collision Detection).
    V3 ab = b - a, ac = c - a, ap = p - a;
    double d1 = Dot(ab, ap), d2 = Dot(ac, ap);
    auto dist = [&](const V3& q) { return Len(p - q); };
    if (d1 <= 0 && d2 <= 0) return dist(a);
    V3 bp = p - b;
    double d3 = Dot(ab, bp), d4 = Dot(ac, bp);
    if (d3 >= 0 && d4 <= d3) return dist(b);
    double vc = d1 * d4 - d3 * d2;
    if (vc <= 0 && d1 >= 0 && d3 <= 0)
    {
        double v = d1 / (d1 - d3);
        return dist({ a.x + v * ab.x, a.y + v * ab.y, a.z + v * ab.z });
    }
    V3 cp = p - c;
    double d5 = Dot(ab, cp), d6 = Dot(ac, cp);
    if (d6 >= 0 && d5 <= d6) return dist(c);
    double vb = d5 * d2 - d1 * d6;
    if (vb <= 0 && d2 >= 0 && d6 <= 0)
    {
        double w = d2 / (d2 - d6);
        return dist({ a.x + w * ac.x, a.y + w * ac.y, a.z + w * ac.z });
    }
    double va = d3 * d6 - d5 * d4;
    if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0)
    {
        double w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
        return dist({ b.x + w * (c.x - b.x), b.y + w * (c.y - b.y), b.z + w * (c.z - b.z) });
    }
    double denom = 1.0 / (va + vb + vc);
    double v = vb * denom, w = vc * denom;
    return dist({ a.x + ab.x * v + ac.x * w, a.y + ab.y * v + ac.y * w, a.z + ab.z * v + ac.z * w });
}

// Позиции вершин на кадре: сумма по весам (поворот(q) * p + t). frame < 0 — поза привязки.
static std::vector<V3> Skin(const Oss& m, int frame)
{
    std::vector<V3> out = m.pos;
    if (frame < 0)
        return out;
    const float* f = reinterpret_cast<const float*>(m.frameData.data()) + static_cast<size_t>(frame) * m.bones * 7;
    for (size_t i = 0; i < m.pos.size(); ++i)
    {
        V3 acc;
        for (const Weight& w : m.weights[i])
        {
            const float* b = f + static_cast<size_t>(w.bone) * 7;
            double qx = b[3], qy = b[4], qz = b[5], qw = b[6];
            const V3& p = m.pos[i];
            // v' = v + 2 * cross(q.xyz, cross(q.xyz, v) + w * v)
            V3 q{ qx, qy, qz };
            V3 t1 = Cross(q, p);
            t1 = { t1.x + qw * p.x, t1.y + qw * p.y, t1.z + qw * p.z };
            V3 t2 = Cross(q, t1);
            V3 r{ p.x + 2 * t2.x + b[0], p.y + 2 * t2.y + b[1], p.z + 2 * t2.z + b[2] };
            acc = { acc.x + w.w * r.x, acc.y + w.w * r.y, acc.z + w.w * r.z };
        }
        out[i] = acc;
    }
    return out;
}

int main(int argc, char** argv)
{
    if (argc < 2)
    {
        std::printf("usage: decimate_test <game dir> [ratio...]\n");
        return 2;
    }
    std::vector<float> ratios;
    for (int i = 2; i < argc; ++i)
        ratios.push_back(static_cast<float>(std::atof(argv[i])));
    if (ratios.empty())
        ratios = { 0.6f, 0.35f };

    fs::path dir = fs::path(argv[1]) / "data" / "actors" / "units";
    std::vector<fs::path> files;
    for (const auto& e : fs::directory_iterator(dir))
        if (e.path().extension() == ".oss")
            files.push_back(e.path());
    std::sort(files.begin(), files.end());

    int failures = 0;
    for (float ratio : ratios)
    {
        long trisBefore = 0, trisAfter = 0;
        double worstBind = 0, worstAnim = 0, sumAnim = 0;
        std::string worstName;
        int n = 0;
        for (const fs::path& f : files)
        {
            std::ifstream in(f, std::ios::binary);
            std::stringstream ss;
            ss << in.rdbuf();
            std::string src = ss.str(), dst, err;
            ModelDecimate::Stats st;
            if (!ModelDecimate::DecimateOss(src, ratio, &dst, &st, &err))
            {
                std::printf("FAIL %s: %s\n", f.filename().string().c_str(), err.c_str());
                ++failures;
                continue;
            }
            Oss a, b;
            if (!ParseOss(src, &a, &err) || !ParseOss(dst, &b, &err))
            {
                std::printf("FAIL %s: результат не разбирается: %s\n", f.filename().string().c_str(), err.c_str());
                ++failures;
                continue;
            }
            bool bad = a.frameData != b.frameData || a.frames != b.frames || a.bones != b.bones;
            for (const Tri& t : b.tris)
                if (t.p[0] == t.p[1] || t.p[1] == t.p[2] || t.p[0] == t.p[2])
                    bad = true;
            for (const auto& w : b.weights)
            {
                float sum = 0;
                for (const Weight& x : w)
                    sum += x.w;
                if (w.empty() || std::fabs(sum - 1.0f) > 1e-3f)
                    bad = true;
            }
            if (bad)
            {
                std::printf("FAIL %s: кадры/индексы/веса испорчены\n", f.filename().string().c_str());
                ++failures;
                continue;
            }
            trisBefore += st.trisBefore;
            trisAfter += st.trisAfter;

            // Отклонение в долях диагонали.
            V3 lo = a.pos[0], hi = a.pos[0];
            for (const V3& p : a.pos)
            {
                lo = { std::min(lo.x, p.x), std::min(lo.y, p.y), std::min(lo.z, p.z) };
                hi = { std::max(hi.x, p.x), std::max(hi.y, p.y), std::max(hi.z, p.z) };
            }
            double diag = Len(hi - lo);
            std::vector<int> frames = { -1 };
            for (int k = 1; k <= 6 && a.frames > 0; ++k)
                frames.push_back((a.frames - 1) * k / 6);
            double worstHere = 0, bindHere = 0;
            for (int fr : frames)
            {
                std::vector<V3> pa = Skin(a, fr), pb = Skin(b, fr);
                double worst = 0;
                for (const V3& p : pa)
                {
                    double best = 1e30;
                    for (const Tri& t : b.tris)
                        best = std::min(best, PointTri(p, pb[t.p[0]], pb[t.p[1]], pb[t.p[2]]));
                    worst = std::max(worst, best);
                }
                worst /= diag;
                if (fr < 0)
                    bindHere = worst;
                else
                    worstHere = std::max(worstHere, worst);
            }
            worstBind = std::max(worstBind, bindHere);
            if (bindHere > 0.05 || worstHere > 0.08)
                std::printf("    %-24s tris %d->%d  bind %.3f  anim %.3f\n", f.filename().string().c_str(), st.trisBefore, st.trisAfter, bindHere, worstHere);
            sumAnim += worstHere;
            ++n;
            if (worstHere > worstAnim)
                worstAnim = worstHere, worstName = f.filename().string();
        }
        std::printf("доля %.2f: треугольников %ld -> %ld (%.0f%%), моделей %d\n", ratio, trisBefore, trisAfter,
                    100.0 * trisAfter / std::max(1L, trisBefore), n);
        std::printf("  отклонение, доля диагонали: поза привязки max %.4f; анимация max %.4f (%s), среднее по моделям %.4f\n",
                    worstBind, worstAnim, worstName.c_str(), n ? sumAnim / n : 0.0);
    }
    std::printf(failures ? "ПРОВАЛОВ: %d\n" : "ok\n", failures);
    return failures ? 1 : 0;
}
