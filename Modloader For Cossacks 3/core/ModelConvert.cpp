#include "pch.h"
#include "ModelConvert.h"

#include <cmath>
#include <cstring>
#include <functional>
#include <vector>
#include <wincodec.h>

#pragma comment(lib, "windowscodecs.lib")

namespace
{
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

    void Put32(std::string& s, uint32_t v) { s.append(reinterpret_cast<const char*>(&v), 4); }
    void PutF(std::string& s, float v) { s.append(reinterpret_cast<const char*>(&v), 4); }
}

bool ModelConvert::GlbToOsm(const std::string& glb, std::string* osm, std::string* image, Stats* stats, std::string* error)
{
    Glb g;
    if (!ParseGlb(glb, &g, error))
        return false;

    std::vector<float> pos, uv; // игровые координаты и UV — по вершине
    std::vector<int> tris;      // уже в порядке игры
    int meshes = 0;
    std::string firstImage;

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
                if (firstImage.empty())
                    firstImage = MaterialImage(g, prim);
            }
        }
        if (const Json* children = node->Get("children"))
            for (const Json& c : children->array)
                if (!visit(static_cast<int>(c.number), world, depth + 1))
                    return false;
        return true;
    };

    const Json* scenes = g.json.Get("scenes");
    const Json* scene = scenes ? scenes->At(g.json.Int("scene", 0)) : nullptr;
    if (scene && scene->Get("nodes"))
    {
        for (const Json& root : scene->Get("nodes")->array)
            if (!visit(static_cast<int>(root.number), Identity(), 0))
                return false;
    }
    else if (nodes)
        for (size_t i = 0; i < nodes->array.size(); ++i)
            if (!visit(static_cast<int>(i), Identity(), 0))
                return false;

    int nv = static_cast<int>(pos.size() / 3), nt = static_cast<int>(tris.size() / 3);
    if (nv == 0 || nt == 0)
        return *error = "no triangle meshes in the .glb", false;

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
    if (image)
        *image = std::move(firstImage);
    if (stats)
        *stats = { nv, nt, meshes };
    return true;
}

bool ModelConvert::ImageToDds(const std::string& image, bool playerColor, std::string* dds, std::string* error)
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

    // Альфа = маска цвета игрока. Непрозрачная картинка (альфа везде 255) — значит маски нет.
    bool hasMask = false;
    for (size_t i = 3; i < px.size() && !hasMask; i += 4)
        hasMask = px[i] != 255;
    if (!playerColor || !hasMask)
        for (size_t i = 3; i < px.size(); i += 4)
            px[i] = 0;

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

    std::string out = "DDS ";
    uint32_t header[31] = {};
    header[0] = 124;                                                   // dwSize
    header[1] = 0x1 | 0x2 | 0x4 | 0x8 | 0x1000 | 0x20000;              // CAPS HEIGHT WIDTH PITCH PIXELFORMAT MIPMAPCOUNT
    header[2] = h;
    header[3] = w;
    header[4] = w * 4;                                                 // pitch
    header[6] = static_cast<uint32_t>(levels.size());
    header[18] = 32;                                                   // pixel format size
    header[19] = 0x41;                                                 // RGB | ALPHAPIXELS
    header[21] = 32;
    header[22] = 0x00FF0000;
    header[23] = 0x0000FF00;
    header[24] = 0x000000FF;
    header[25] = 0xFF000000;
    header[26] = 0x1000 | 0x400000 | 0x8;                              // TEXTURE | MIPMAP | COMPLEX
    out.append(reinterpret_cast<const char*>(header), sizeof(header));
    for (const auto& l : levels)
        out.append(reinterpret_cast<const char*>(l.data()), l.size());
    *dds = std::move(out);
    return true;
}
