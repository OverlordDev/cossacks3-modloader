#include "pch.h"
#include "ModelDecimate.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <functional>
#include <queue>
#include <utility>
#include <vector>

namespace
{
    struct V3
    {
        double x = 0, y = 0, z = 0;
    };
    V3 operator-(const V3& a, const V3& b) { return { a.x - b.x, a.y - b.y, a.z - b.z }; }
    double Dot(const V3& a, const V3& b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
    V3 Cross(const V3& a, const V3& b) { return { a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x }; }
    double Len(const V3& a) { return std::sqrt(Dot(a, a)); }

    // Квадрика: сумма квадратов расстояний до набора плоскостей (симметричная матрица 4x4).
    struct Quadric
    {
        double q[10] = {};

        void AddPlane(const V3& n, double d, double w)
        {
            q[0] += w * n.x * n.x; q[1] += w * n.x * n.y; q[2] += w * n.x * n.z; q[3] += w * n.x * d;
            q[4] += w * n.y * n.y; q[5] += w * n.y * n.z; q[6] += w * n.y * d;
            q[7] += w * n.z * n.z; q[8] += w * n.z * d;
            q[9] += w * d * d;
        }
        Quadric& operator+=(const Quadric& o)
        {
            for (int i = 0; i < 10; ++i)
                q[i] += o.q[i];
            return *this;
        }
        double Eval(const V3& p) const
        {
            return q[0] * p.x * p.x + 2 * q[1] * p.x * p.y + 2 * q[2] * p.x * p.z + 2 * q[3] * p.x +
                   q[4] * p.y * p.y + 2 * q[5] * p.y * p.z + 2 * q[6] * p.y +
                   q[7] * p.z * p.z + 2 * q[8] * p.z + q[9];
        }
    };

    struct Tri
    {
        int p[3];  // вершины (позиции)
        int t[3];  // текстурные координаты углов — у каждого угла свои, шов UV остаётся швом
        bool alive = true;
    };

    struct Weight { int bone; float w; };

    struct Oss
    {
        int32_t frames = 0, fps = 0, bones = 0;
        std::vector<V3> pos;
        std::vector<Tri> tris;
        std::vector<float> uv; // u, v
        std::vector<std::vector<Weight>> weights;
        std::string frameData; // кадры костей как есть
    };

    class Reader
    {
    public:
        explicit Reader(const std::string& s) : m_s(s) {}
        bool Read(void* dst, size_t n)
        {
            if (m_pos + n > m_s.size())
                return false;
            std::memcpy(dst, m_s.data() + m_pos, n);
            m_pos += n;
            return true;
        }
        template <class T> bool Get(T* v) { return Read(v, sizeof(T)); }
        size_t Left() const { return m_s.size() - m_pos; }
        std::string Rest()
        {
            std::string r = m_s.substr(m_pos);
            m_pos = m_s.size();
            return r;
        }

    private:
        const std::string& m_s;
        size_t m_pos = 0;
    };

    bool ParseOss(const std::string& data, Oss* m, std::string* err)
    {
        Reader r(data);
        int32_t nv, nt, nu;
        if (!r.Get(&m->frames) || !r.Get(&m->fps) || !r.Get(&m->bones) || !r.Get(&nv) || !r.Get(&nt) || !r.Get(&nu))
        {
            *err = "файл короче заголовка";
            return false;
        }
        if (nv <= 0 || nt <= 0 || nu <= 0 || nv > 1000000 || nt > 2000000 || nu > 2000000 || m->frames < 0 || m->bones <= 0)
        {
            *err = "заголовок .oss не похож на правду";
            return false;
        }
        m->pos.resize(nv);
        for (V3& p : m->pos)
        {
            float f[3];
            if (!r.Read(f, 12))
            {
                *err = "оборвано на позициях";
                return false;
            }
            p = { f[0], f[1], f[2] };
        }
        m->tris.resize(nt);
        for (Tri& t : m->tris)
        {
            uint32_t v[3];
            if (!r.Read(v, 12))
            {
                *err = "оборвано на треугольниках";
                return false;
            }
            for (int i = 0; i < 3; ++i)
            {
                if (v[i] >= static_cast<uint32_t>(nv))
                {
                    *err = "индекс вершины вне диапазона";
                    return false;
                }
                t.p[i] = static_cast<int>(v[i]);
            }
        }
        m->uv.resize(static_cast<size_t>(nu) * 2);
        if (!r.Read(m->uv.data(), m->uv.size() * 4))
        {
            *err = "оборвано на UV";
            return false;
        }
        for (Tri& t : m->tris)
        {
            uint32_t v[3];
            if (!r.Read(v, 12))
            {
                *err = "оборвано на UV треугольников";
                return false;
            }
            for (int i = 0; i < 3; ++i)
            {
                if (v[i] >= static_cast<uint32_t>(nu))
                {
                    *err = "индекс UV вне диапазона";
                    return false;
                }
                t.t[i] = static_cast<int>(v[i]);
            }
        }
        m->weights.resize(nv);
        for (auto& list : m->weights)
        {
            int32_t n;
            if (!r.Get(&n) || n < 0 || n > 64)
            {
                *err = "оборвано на весах";
                return false;
            }
            list.resize(n);
            for (Weight& w : list)
            {
                int32_t bone;
                float weight;
                if (!r.Get(&bone) || !r.Get(&weight))
                {
                    *err = "оборвано на весах";
                    return false;
                }
                w = { bone, weight };
            }
        }
        size_t frameBytes = static_cast<size_t>(m->frames) * m->bones * 28;
        if (r.Left() != frameBytes)
        {
            *err = "размер блока кадров не сходится с заголовком";
            return false;
        }
        m->frameData = r.Rest();
        return true;
    }

    template <class T> void Put(std::string* out, const T& v) { out->append(reinterpret_cast<const char*>(&v), sizeof(T)); }

    std::string WriteOss(const Oss& m, const std::vector<int>& keepVerts, const std::vector<int>& vertRemap,
                         const std::vector<int>& keepUv, const std::vector<int>& uvRemap)
    {
        std::vector<const Tri*> tris;
        for (const Tri& t : m.tris)
            if (t.alive)
                tris.push_back(&t);
        std::string out;
        Put<int32_t>(&out, m.frames);
        Put<int32_t>(&out, m.fps);
        Put<int32_t>(&out, m.bones);
        Put<int32_t>(&out, static_cast<int32_t>(keepVerts.size()));
        Put<int32_t>(&out, static_cast<int32_t>(tris.size()));
        Put<int32_t>(&out, static_cast<int32_t>(keepUv.size()));
        for (int v : keepVerts)
        {
            Put<float>(&out, static_cast<float>(m.pos[v].x));
            Put<float>(&out, static_cast<float>(m.pos[v].y));
            Put<float>(&out, static_cast<float>(m.pos[v].z));
        }
        for (const Tri* t : tris)
            for (int i = 0; i < 3; ++i)
                Put<uint32_t>(&out, static_cast<uint32_t>(vertRemap[t->p[i]]));
        for (int u : keepUv)
        {
            Put<float>(&out, m.uv[static_cast<size_t>(u) * 2]);
            Put<float>(&out, m.uv[static_cast<size_t>(u) * 2 + 1]);
        }
        for (const Tri* t : tris)
            for (int i = 0; i < 3; ++i)
                Put<uint32_t>(&out, static_cast<uint32_t>(uvRemap[t->t[i]]));
        for (int v : keepVerts)
        {
            Put<int32_t>(&out, static_cast<int32_t>(m.weights[v].size()));
            for (const Weight& w : m.weights[v])
            {
                Put<int32_t>(&out, w.bone);
                Put<float>(&out, w.w);
            }
        }
        out += m.frameData;
        return out;
    }

    bool HasVert(const Tri& t, int v) { return t.p[0] == v || t.p[1] == v || t.p[2] == v; }

    struct Edge
    {
        double cost;
        int a, b; // a схлопывается в b
        unsigned va, vb;
        bool operator>(const Edge& o) const { return cost > o.cost; }
    };

    class Simplifier
    {
    public:
        explicit Simplifier(Oss* m) : m_m(m), m_alive(m->pos.size(), true), m_ver(m->pos.size(), 0), m_vt(m->pos.size()), m_q(m->pos.size())
        {
            Normalize();
            for (int i = 0; i < static_cast<int>(m_m->tris.size()); ++i)
                for (int c = 0; c < 3; ++c)
                    m_vt[m_m->tris[i].p[c]].push_back(i);
            BuildQuadrics();
            m_bone.resize(m_m->pos.size());
            for (size_t v = 0; v < m_bone.size(); ++v)
            {
                int best = -1;
                float bw = -1;
                for (const Weight& w : m_m->weights[v])
                    if (w.w > bw)
                        bw = w.w, best = w.bone;
                m_bone[v] = best;
            }
        }

        int Alive() const { return m_aliveTris; }

        void Run(int targetTris)
        {
            std::priority_queue<Edge, std::vector<Edge>, std::greater<Edge>> heap;
            auto push = [&](int a, int b) {
                heap.push({ Cost(a, b), a, b, m_ver[a], m_ver[b] });
            };
            for (const Tri& t : m_m->tris)
                for (int c = 0; c < 3; ++c)
                {
                    int a = t.p[c], b = t.p[(c + 1) % 3];
                    push(a, b);
                    push(b, a);
                }
            while (m_aliveTris > targetTris && !heap.empty())
            {
                Edge e = heap.top();
                heap.pop();
                if (!m_alive[e.a] || !m_alive[e.b] || e.va != m_ver[e.a] || e.vb != m_ver[e.b])
                    continue;
                if (!CanCollapse(e.a, e.b))
                    continue;
                Collapse(e.a, e.b);
                // Цена рёбер вокруг b изменилась (у b новая квадрика и новое окружение).
                for (int n : Neighbors(e.b))
                {
                    push(n, e.b);
                    push(e.b, n);
                }
            }
        }

        // Кто остался: вершины, UV, перенумерация.
        void Survivors(std::vector<int>* keepV, std::vector<int>* remapV, std::vector<int>* keepUv, std::vector<int>* remapUv) const
        {
            remapV->assign(m_m->pos.size(), -1);
            remapUv->assign(m_m->uv.size() / 2, -1);
            for (const Tri& t : m_m->tris)
            {
                if (!t.alive)
                    continue;
                for (int i = 0; i < 3; ++i)
                {
                    if ((*remapV)[t.p[i]] < 0)
                    {
                        (*remapV)[t.p[i]] = static_cast<int>(keepV->size());
                        keepV->push_back(t.p[i]);
                    }
                    if ((*remapUv)[t.t[i]] < 0)
                    {
                        (*remapUv)[t.t[i]] = static_cast<int>(keepUv->size());
                        keepUv->push_back(t.t[i]);
                    }
                }
            }
        }

        double Scale() const { return m_scale; }
        V3 Origin() const { return m_origin; }

    private:
        // Работаем в единичном кубе: штрафы ниже не зависят от размера модели. Позиции пишутся обратно
        // из исходных чисел (Restore), так что оставшиеся вершины остаются байт-в-байт прежними.
        void Normalize()
        {
            V3 lo = m_m->pos[0], hi = m_m->pos[0];
            for (const V3& p : m_m->pos)
            {
                lo = { std::min(lo.x, p.x), std::min(lo.y, p.y), std::min(lo.z, p.z) };
                hi = { std::max(hi.x, p.x), std::max(hi.y, p.y), std::max(hi.z, p.z) };
            }
            m_origin = lo;
            m_scale = std::max(1e-9, Len(hi - lo));
            m_orig = m_m->pos;
            for (V3& p : m_m->pos)
                p = { (p.x - lo.x) / m_scale, (p.y - lo.y) / m_scale, (p.z - lo.z) / m_scale };
            m_aliveTris = static_cast<int>(m_m->tris.size());
        }

    public:
        void Restore()
        {
            for (size_t i = 0; i < m_m->pos.size(); ++i)
                m_m->pos[i] = m_orig[i];
        }

    private:
        static bool Normal(const V3& a, const V3& b, const V3& c, V3* n, double* area2)
        {
            V3 x = Cross(b - a, c - a);
            *area2 = Len(x);
            if (*area2 < 1e-16)
                return false;
            *n = { x.x / *area2, x.y / *area2, x.z / *area2 };
            return true;
        }

        void BuildQuadrics()
        {
            for (const Tri& t : m_m->tris)
            {
                V3 n;
                double a2;
                if (!Normal(m_m->pos[t.p[0]], m_m->pos[t.p[1]], m_m->pos[t.p[2]], &n, &a2))
                    continue;
                double d = -Dot(n, m_m->pos[t.p[0]]);
                for (int c = 0; c < 3; ++c)
                    m_q[t.p[c]].AddPlane(n, d, a2 * 0.5);
            }
            // Края открытой сетки: плоскость вдоль ребра, перпендикулярная треугольнику.
            for (int i = 0; i < static_cast<int>(m_m->tris.size()); ++i)
            {
                const Tri& t = m_m->tris[i];
                V3 n;
                double a2;
                if (!Normal(m_m->pos[t.p[0]], m_m->pos[t.p[1]], m_m->pos[t.p[2]], &n, &a2))
                    continue;
                for (int c = 0; c < 3; ++c)
                {
                    int a = t.p[c], b = t.p[(c + 1) % 3];
                    if (EdgeUse(a, b) != 1)
                        continue;
                    V3 e = m_m->pos[b] - m_m->pos[a];
                    V3 m = Cross(n, e);
                    double ml = Len(m);
                    if (ml < 1e-16)
                        continue;
                    m = { m.x / ml, m.y / ml, m.z / ml };
                    double len = Len(e);
                    double d = -Dot(m, m_m->pos[a]);
                    m_q[a].AddPlane(m, d, 10 * len * len);
                    m_q[b].AddPlane(m, d, 10 * len * len);
                }
            }
        }

        int EdgeUse(int a, int b) const
        {
            int n = 0;
            for (int ti : m_vt[a])
            {
                const Tri& t = m_m->tris[ti];
                if (t.alive && HasVert(t, a) && HasVert(t, b))
                    ++n;
            }
            return n;
        }

        // Треугольники, в которых сейчас есть вершина v.
        std::vector<int> Incident(int v) const
        {
            std::vector<int> r;
            for (int ti : m_vt[v])
            {
                const Tri& t = m_m->tris[ti];
                if (t.alive && HasVert(t, v))
                    r.push_back(ti);
            }
            std::sort(r.begin(), r.end());
            r.erase(std::unique(r.begin(), r.end()), r.end());
            return r;
        }

        std::vector<int> Neighbors(int v) const
        {
            std::vector<int> r;
            for (int ti : Incident(v))
                for (int c = 0; c < 3; ++c)
                    if (m_m->tris[ti].p[c] != v)
                        r.push_back(m_m->tris[ti].p[c]);
            std::sort(r.begin(), r.end());
            r.erase(std::unique(r.begin(), r.end()), r.end());
            return r;
        }

        bool IsBoundary(int v) const
        {
            for (int n : Neighbors(v))
                if (EdgeUse(v, n) == 1)
                    return true;
            return false;
        }

        double Cost(int a, int b) const
        {
            Quadric q = m_q[a];
            q += m_q[b];
            double cost = std::max(0.0, q.Eval(m_m->pos[b]));
            double len2 = Dot(m_m->pos[a] - m_m->pos[b], m_m->pos[a] - m_m->pos[b]);
            double ring = 0;
            double uvMax = 0;
            for (int v : { a, b })
                for (int ti : Incident(v))
                {
                    const Tri& t = m_m->tris[ti];
                    V3 n;
                    double a2;
                    if (Normal(m_m->pos[t.p[0]], m_m->pos[t.p[1]], m_m->pos[t.p[2]], &n, &a2))
                        ring += a2 * 0.5;
                    if (v == a && HasVert(t, b))
                    {
                        int ca = t.p[0] == a ? 0 : t.p[1] == a ? 1 : 2;
                        int cb = t.p[0] == b ? 0 : t.p[1] == b ? 1 : 2;
                        double du = m_m->uv[static_cast<size_t>(t.t[ca]) * 2] - m_m->uv[static_cast<size_t>(t.t[cb]) * 2];
                        double dv = m_m->uv[static_cast<size_t>(t.t[ca]) * 2 + 1] - m_m->uv[static_cast<size_t>(t.t[cb]) * 2 + 1];
                        uvMax = std::max(uvMax, std::sqrt(du * du + dv * dv));
                    }
                }
            // Сустав: точка уедет вместе с чужой костью — при анимации тянет треугольники.
            if (m_bone[a] != m_bone[b])
                cost += 4.0 * len2 * ring;
            // Текстура: угол оставляет свои UV, а тело сместилось — картинка «съезжает» на длину ребра в UV.
            cost += 0.5 * uvMax * uvMax * ring;
            return cost;
        }

        bool CanCollapse(int a, int b) const
        {
            std::vector<int> ta = Incident(a);
            int shared = 0;
            for (int ti : ta)
                if (HasVert(m_m->tris[ti], b))
                    ++shared;
            if (shared == 0)
                return false;

            // Ребро не должно складывать сетку: общие соседи a и b — только противоположные вершины
            // двух (или одного) треугольников на ребре.
            std::vector<int> na = Neighbors(a), nb = Neighbors(b);
            int common = 0;
            for (int n : na)
                if (n != b && std::binary_search(nb.begin(), nb.end(), n))
                    ++common;
            if (common != shared)
                return false;

            // Края не двигаем внутрь: иначе съедается силуэт (и швы между частями модели).
            if (IsBoundary(a) && EdgeUse(a, b) != 1)
                return false;

            for (int ti : ta)
            {
                const Tri& t = m_m->tris[ti];
                if (HasVert(t, b))
                    continue;
                V3 no, nn;
                double ao, an;
                if (!Normal(m_m->pos[t.p[0]], m_m->pos[t.p[1]], m_m->pos[t.p[2]], &no, &ao))
                    continue;
                V3 pv[3];
                for (int c = 0; c < 3; ++c)
                    pv[c] = m_m->pos[t.p[c] == a ? b : t.p[c]];
                if (!Normal(pv[0], pv[1], pv[2], &nn, &an))
                    return false;
                if (Dot(no, nn) < 0.2)
                    return false;
            }
            return true;
        }

        void Collapse(int a, int b)
        {
            for (int ti : Incident(a))
            {
                Tri& t = m_m->tris[ti];
                if (HasVert(t, b))
                {
                    t.alive = false;
                    --m_aliveTris;
                    continue;
                }
                for (int c = 0; c < 3; ++c)
                    if (t.p[c] == a)
                        t.p[c] = b;
                m_vt[b].push_back(ti);
            }
            m_q[b] += m_q[a];
            m_alive[a] = false;
            ++m_ver[a];
            ++m_ver[b];
        }

        Oss* m_m;
        std::vector<bool> m_alive;
        std::vector<unsigned> m_ver;
        std::vector<std::vector<int>> m_vt;
        std::vector<Quadric> m_q;
        std::vector<int> m_bone;
        std::vector<V3> m_orig;
        V3 m_origin;
        double m_scale = 1;
        int m_aliveTris = 0;
    };
}

bool ModelDecimate::DecimateOss(const std::string& oss, float ratio, std::string* out, Stats* stats, std::string* error)
{
    Oss m;
    std::string err;
    if (!ParseOss(oss, &m, &err))
    {
        if (error)
            *error = err;
        return false;
    }
    Stats local;
    Stats& st = stats ? *stats : local;
    st.vertsBefore = static_cast<int>(m.pos.size());
    st.trisBefore = static_cast<int>(m.tris.size());
    ratio = std::clamp(ratio, 0.05f, 1.0f);
    if (ratio >= 0.999f || st.trisBefore < kMinTriangles)
    {
        *out = oss;
        st.vertsAfter = st.vertsBefore;
        st.trisAfter = st.trisBefore;
        return true;
    }

    Simplifier s(&m);
    int target = std::max(kMinTriangles / 2, static_cast<int>(st.trisBefore * ratio + 0.5f));
    s.Run(target);
    s.Restore();

    std::vector<int> keepV, remapV, keepUv, remapUv;
    s.Survivors(&keepV, &remapV, &keepUv, &remapUv);
    *out = WriteOss(m, keepV, remapV, keepUv, remapUv);
    st.vertsAfter = static_cast<int>(keepV.size());
    st.trisAfter = s.Alive();
    return true;
}
