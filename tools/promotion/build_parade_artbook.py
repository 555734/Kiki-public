"""Build the stage 1-9 design book without editing generated paintings."""
from pathlib import Path
import hashlib
import html
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/promotion/parade-artbook-v1'
EXPORT = ROOT / 'build/promotion/stage-1-9/artbook-v1'
SOURCE = ROOT / 'src/levels/level_parade_data.gd'

ZONES = [
    ('FALSE ENTRANCE', '偽入口', '下顎が橋になる仮面門',
     '主人公が噛みつきを避け、相棒が頬の留め金を撃つ。',
     '開いた橋を小鬼も渡る。通路を作った直後に追跡が始まる。',
     '上に描いた足場へ退避し、群れを先に通す。'),
    ('BACKSTAGE', '舞台裏', '幕と対重で上下の通路を入れ替える',
     '相棒が留め金を撃ち、主人公が下がる対重に乗るか上の通路へ移る。',
     '幕が開いた先には竹馬の案内役。安全だった高さが危険に変わる。',
     '下に受け足場を描く。案内役の膝を撃つと脚が斜面になる。'),
    ('PARADE CROSSING', 'パレードの交差点', '回り舞台で群れの出口を変える',
     '相棒がクラッチを撃って回転を切り替え、主人公が空いた出口へ進む。',
     '鼓笛隊長の合図で群れが一斉に跳び、上のルートにも迫る。',
     '合図の振り上げを見て足場を描く。下の砲台の射線へ群れを誘導する。'),
    ('ACCORDION GAP', '蛇腹の谷', '敵の重みを貯めて跳ぶ',
     '主人公が橋に乗り、相棒が圧縮を見てばねを解放し、着地点を描く。',
     '主人公と敵が一緒に飛ぶ。風船道化の重りも圧縮量を変える。',
     '解放前に受け足場を用意する。橋に残った敵を次の跳躍に使う。'),
    ('SPOTLIGHT GALLERY', '照明回廊', '敵と足場が照明で切り替わる',
     '相棒が照明の向きを切り替え、主人公が暗くなった側を通る。',
     '足場にした小道具が再点灯で人形に戻って動き出す。',
     '照明は二方向を予告して切り替える。足場を別に描いて逃げ道を確保する。'),
    ('SKY WHEEL FINALE', '観覧車の終幕', '群れの重さでゴンドラが動く',
     '主人公が乗り移り、相棒がブレーキを撃って停車し、渡り足場を描く。',
     '反対側のゴンドラに敵が乗ると釣り合いが変わる。追跡者が移動の助けになる。',
     '停車したゴンドラで姿勢を立て直す。最後は本物の赤旗へ渡る。'),
]

CAST = [
    ('WIND-UP GREMLIN', 'ぜんまい小鬼', '既存の敵。群れの重さで橋と観覧車を動かす。'),
    ('DRUM MAJOR', '鼓笛隊長', '振り上げを予告に、周囲の小鬼を一斉に跳ばせる。'),
    ('STILT USHER', '竹馬の案内役', '高い通路を掃く。膝を撃つと脚が一時的な斜面になる。'),
    ('BALLOON HARLEQUIN', '風船道化', 'ひもを撃つと重りが落ち、群れや橋に作用する。'),
    ('SHADOW MARIONETTE', '影の人形', '光の中で敵、暗い場所で固い小道具になる。'),
]


def vec(name, source):
    pattern = rf'static func {name}\(\).*?return Vector2\(([-\d.]+), ([-\d.]+)\)'
    found = re.search(pattern, source)
    if not found:
        raise ValueError(f'missing source vector: {name}')
    return tuple(float(v) for v in found.groups())


def read_geometry():
    source = SOURCE.read_text(encoding='utf-8')
    grounds = [tuple(float(v) for v in match) for match in
               re.findall(r'Rect2\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)', source)]
    checkpoint_section = source.split('static func checkpoints()')[1].split('static func coins()')[0]
    checkpoints = [tuple(float(v) for v in match) for match in
                   re.findall(r'Vector2\(([-\d.]+), ([-\d.]+)\)', checkpoint_section)]
    enemy_section = source.split('static func enemies()')[1].split('static func gimmicks()')[0]
    counts = [int(v) for v in re.findall(r'for i in (\d+):', enemy_section)]
    formulas = re.findall(r'"pos": Vector2\(([-\d.]+) \+ i \* ([\d.]+), ([\d.]+)\)', enemy_section)
    if len(counts) != len(formulas):
        raise ValueError('enemy wave source no longer matches parser')
    waves = [[(float(a) + i * float(b), float(y)) for i in range(n)]
             for n, (a, b, y) in zip(counts, formulas)]
    machines = []
    for body in re.findall(r'\{([^{}]+)\}', source.split('static func gimmicks()')[1], re.S):
        kind = re.search(r'"type": "([^"]+)"', body).group(1)
        pos = tuple(float(v) for v in re.search(r'"pos": Vector2\(([-\d.]+), ([-\d.]+)\)', body).groups())
        item = {'type': kind, 'pos': pos}
        for key in ('kind', 'id'):
            found = re.search(rf'"{key}": "([^"]+)"', body)
            if found:
                item[key] = found.group(1)
        for key in ('span', 'travel'):
            found = re.search(rf'"{key}": Vector2\(([-\d.]+), ([-\d.]+)\)', body)
            if found:
                item[key] = tuple(float(v) for v in found.groups())
        height = re.search(r'"height": ([\d.]+)', body)
        if height:
            item['height'] = float(height.group(1))
        machines.append(item)
    return {'source': str(SOURCE.relative_to(ROOT)).replace('\\', '/'),
            'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            'ground': grounds, 'gimmicks': machines, 'enemy_waves': waves,
            'start': vec('start_position', source), 'goal': vec('goal', source),
            'checkpoints': checkpoints, 'kill_y': 1080.0}


def current_map(data):
    x = lambda value: 60 + (value + 1200) * .24
    y = lambda value: 82 + (value + 100) * .22
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1720" height="460" viewBox="0 0 1720 460" role="img" aria-label="Current stage 1-9 source geometry">',
           '<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#af3c2e"/></marker></defs>',
           '<rect width="1720" height="460" rx="14" fill="#fbf2df"/>',
           '<style>text{font-family:Arial,sans-serif;fill:#453324} .small{font-size:13px} .label{font-size:15px;font-weight:bold}</style>',
           '<text x="38" y="39" font-size="24" font-weight="bold">1-9 / CURRENT STAGE GEOMETRY</text>',
           '<text x="38" y="63" class="small">6 TERRAIN PIECES / 9 MACHINES / 72 GREMLINS / SOURCE COORDINATES</text>']
    for value in range(-1000, 5001, 1000):
        px = x(value)
        svg.append(f'<path d="M{px} 85 V355" stroke="#dac9ad" stroke-dasharray="3 6"/><text x="{px-15}" y="382" class="small">{value}</text>')
    for gx, gy, gw, gh in data['ground']:
        svg.append(f'<rect x="{x(gx)}" y="{y(gy)}" width="{gw*.24}" height="{gh*.22}" fill="#257078" stroke="#c8983f" stroke-width="3"/>')
    for wave_index, wave in enumerate(data['enemy_waves']):
        for gx, gy in wave:
            svg.append(f'<circle cx="{x(gx)}" cy="{y(gy)}" r="2.8" fill="#c34d3a"/>')
        gx, gy = wave[len(wave)//2]
        direction = 1 if wave_index == 0 else -1
        svg.append(f'<path d="M{x(gx)-direction*45} {y(gy)-18} h{direction*90}" stroke="#af3c2e" stroke-width="2" marker-end="url(#arrow)"/>')
        svg.append(f'<text x="{x(gx)-42}" y="{y(gy)-29}" class="small">WAVE {wave_index+1}: 36</text>')
    labels = []
    counters = {'mouth': 0, 'hammer': 0, 'crumble': 0, 'moving_platform': 0}
    for item in data['gimmicks']:
        gx, gy = item['pos']
        px, py = x(gx), y(gy)
        kind = item.get('kind', item['type'])
        counters[kind] += 1
        if kind == 'mouth':
            h = item['height']*.22
            svg.append(f'<rect x="{px-24}" y="{py-h}" width="48" height="{h}" rx="16" fill="#c34d3a" stroke="#c8983f" stroke-width="4"/><path d="M{px-17} {py-12} l8 -9 8 9 8 -9 8 9" fill="none" stroke="#fff4df" stroke-width="4"/>')
            labels.append((px, py-h-10, f'MOUTH {counters[kind]}'))
        elif kind == 'hammer':
            h = item['height']*.22
            svg.append(f'<path d="M{px} {py} v{h-6}" stroke="#b68b37" stroke-width="5"/><circle cx="{px}" cy="{py}" r="7" fill="#ffd36c" stroke="#c8983f"/><rect x="{px-25}" y="{py+h-15}" width="50" height="15" rx="3" fill="#c34d3a" stroke="#c8983f" stroke-width="3"/>')
            labels.append((px, py-17, f'HAMMER {counters[kind]}'))
        else:
            sw, sh = item['span']
            fill = '#d18462' if kind == 'crumble' else '#64aeb2'
            svg.append(f'<rect x="{px-sw*.12}" y="{py-sh*.11}" width="{sw*.24}" height="{sh*.22}" fill="{fill}" stroke="#bf973d" stroke-width="2"/>')
            if kind == 'moving_platform':
                tx, ty = item['travel']
                svg.append(f'<path d="M{px} {py} l{tx*.24} {ty*.22}" stroke="#387b88" stroke-width="2" stroke-dasharray="4 3"/>')
            tag = 'CRUMBLE' if kind == 'crumble' else 'LIFT'
            labels.append((px, py+32, f'{tag} {counters[kind]}'))
    for px, py, text in labels:
        svg.append(f'<text x="{px}" y="{py}" text-anchor="middle" class="small">{text}</text>')
    for point, label, color in [(data['start'], 'START', '#236883'), (data['goal'], 'REAL GOAL', '#ba392e')]:
        px, py = x(point[0]), y(point[1])
        svg.append(f'<circle cx="{px}" cy="{py}" r="6" fill="{color}"/><text x="{px}" y="{py-15}" text-anchor="middle" class="label">{label}</text>')
    for i, (gx, gy) in enumerate(data['checkpoints']):
        px, py = x(gx), y(gy)
        svg.append(f'<path d="M{px} {py} v-23 h12 l-4 6 4 6 h-12" fill="#eebf63" stroke="#8d692d"/><text x="{px+5}" y="{py+25}" class="small">CP{i+1}</text>')
    svg += [f'<path d="M45 {y(data["kill_y"])} H1650" stroke="#ba392e" stroke-dasharray="8 7"/><text x="46" y="{y(data["kill_y"])+20}" class="small">FALL RESET LINE / y=1080</text>',
            '<text x="38" y="419" class="small">Level positions are read from level_parade_data.gd. Machine symbols are schematic, not collision shapes.</text>',
            '<text x="38" y="442" class="small">This is the current implementation. The illustrated six-zone map is a separate proposed expansion.</text>', '</svg>']
    return '\n'.join(svg)


def figure(filename, alt):
    return f'<a class="art" href="{filename}" target="_blank" rel="noopener"><img src="{filename}" alt="{alt}" loading="lazy"></a><p class="caption">画像を選ぶと原寸で開きます</p>'


def build_html():
    cards = ''.join(f'<article class="cast"><span class="number">0{i+1}</span><h3>{english}</h3><p class="jp">{japanese}</p><p>{html.escape(detail)}</p></article>'
                    for i, (english, japanese, detail) in enumerate(CAST))
    zones = ''.join(f'<button class="zone" type="button" data-zone="{i}" aria-pressed="{"true" if i == 0 else "false"}"><b>0{i+1}</b><span>{english}<small>{japanese}</small></span></button>'
                    for i, (english, japanese, *_rest) in enumerate(ZONES))
    detail_json = json.dumps([{'title': f'0{i+1} / {a}', 'jp': b, 'device': c, 'operation': d, 'surprise': e, 'rescue': f}
                             for i, (a, b, c, d, e, f) in enumerate(ZONES)], ensure_ascii=False)
    return f'''<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>THE TRICKSTER PARADE · Design book 01</title>
<style>
:root{{--paper:#fbf3e4;--ink:#342a25;--coral:#a43e32;--teal:#276773;--gold:#b38b48}}*{{box-sizing:border-box}}html{{scroll-behavior:smooth}}body{{margin:0;background:#ece1cf;color:var(--ink);font-family:Arial,'Yu Gothic',sans-serif;line-height:1.8}}header,main,footer{{max-width:1480px;margin:auto;padding:32px 40px}}header{{padding-top:62px}}.eyebrow{{font-size:12px;letter-spacing:.18em;color:var(--coral);font-weight:bold}}h1{{font-family:Georgia,serif;font-size:clamp(32px,4.5vw,70px);line-height:1.05;margin:17px 0}}h2{{font-family:Georgia,serif;font-size:32px;line-height:1.25;margin:0 0 12px}}h3{{font-size:16px;line-height:1.4;margin:8px 0}}p{{margin:8px 0 20px}}.intro{{max-width:850px}}.meta,.caption{{font-size:12px;color:#6e6255}}nav{{position:sticky;top:0;z-index:2;background:#fbf3e4ee;border-top:1px solid #cab898;border-bottom:1px solid #cab898;backdrop-filter:blur(8px)}}nav div{{max-width:1480px;margin:auto;padding:10px 40px;display:flex;gap:26px;overflow:auto;white-space:nowrap}}a{{color:var(--teal)}}nav a{{text-decoration:none;font-size:13px;font-weight:bold}}section{{scroll-margin-top:70px;margin-bottom:58px;background:var(--paper);border:1px solid #d4c1a4;padding:28px}}.label{{color:var(--coral);font-size:12px;letter-spacing:.13em;margin:0 0 8px}}.art{{display:block}}.art img{{display:block;width:100%;height:auto}}.caption{{margin:6px 0 0;text-align:right}}.deck{{max-width:1000px}}.cast-grid{{display:grid;grid-template-columns:repeat(5,1fr);gap:16px;margin-top:20px}}.cast{{border-top:2px solid var(--gold);padding:12px 5px}}.cast p{{font-size:13px}}.cast .jp{{color:var(--coral);margin-bottom:8px;font-size:14px}}.number{{font-size:12px;color:var(--gold)}}.zones{{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:22px 0 18px}}button{{font:inherit;cursor:pointer}}.zone{{display:flex;gap:12px;align-items:center;text-align:left;background:#f6ead5;border:1px solid #ceb894;color:var(--ink);padding:14px}}.zone b{{font:28px Georgia,serif;color:var(--coral)}}.zone span{{font-size:13px;font-weight:bold}}.zone small{{display:block;font-size:12px;font-weight:normal}}.zone[aria-pressed="true"]{{background:var(--teal);color:white;border-color:var(--teal)}}.zone[aria-pressed="true"] b{{color:#ffda93}}.details{{padding:24px;background:#efe4cf;border-left:4px solid var(--gold)}}.details h3{{font-size:21px;margin-top:0}}.detail-grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:24px}}.detail-grid p{{font-size:14px;margin-bottom:0}}.detail-grid b{{color:var(--coral);font-size:12px}}.source-row{{display:grid;grid-template-columns:320px 1fr;gap:25px;align-items:center;margin:16px 0 22px}}.source-row img{{width:100%}}.note{{padding:16px 20px;background:#efe4cf;font-size:14px}}footer{{font-size:12px;padding-bottom:55px}}:focus-visible{{outline:3px solid #e49531;outline-offset:4px}}@media(max-width:850px){{header,main,footer{{padding:24px 18px}}nav div{{padding:10px 18px;gap:20px}}section{{padding:15px;margin-bottom:30px}}.cast-grid{{grid-template-columns:repeat(2,1fr)}}.zones{{grid-template-columns:repeat(2,1fr)}}.detail-grid{{grid-template-columns:1fr;gap:14px}}.source-row{{grid-template-columns:1fr}}.source-row img{{max-width:400px}}}}@media print{{nav,.caption,.zones,footer{{display:none}}body{{background:white}}header,main{{max-width:none;padding:0}}section{{break-before:page;border:0;padding:0;margin:0 0 20px}}.art img{{max-height:75vh;object-fit:contain}}}}
</style></head><body>
<header><div class="eyebrow">MELOS GAME · DESIGN BOOK 01 · 2026.10.10</div><h1>THE TRICKSTER<br>PARADE</h1><p class="intro">動画の「空に浮かぶからくり劇場」を広げた設定集。舞台装置を動かすと通路と敵の流れが変わり、その結果を見て二人が次の操作を決めます。</p><p class="meta">Art direction exploration · Stage 1−9 · Inoue &amp; Sasabe</p></header>
<nav aria-label="設定集のページ"><div><a href="#world">01 世界観</a><a href="#machines">02 舞台装置</a><a href="#cast">03 敵の設定</a><a href="#map">04 拡張マップ</a><a href="#current">05 現在の配置</a></div></nav>
<main>
<section id="world"><p class="label">01 / WORLD IMAGEBOARD</p><h2>街全体が一つの劇場</h2><p class="deck">珊瑚色の木、青緑の金属、真鍮の歯車、仮面とぜんまい。動画にあった背景の観覧車も、終幕では乗り移って進む舞台装置になります。</p>{figure('01-world-imageboard.png','空に浮かぶ劇場都市のイメージボード。仮面門、舞台裏、観覧車、配色。')}</section>
<section id="machines"><p class="label">02 / STAGE MACHINES</p><h2>装置ごとに違う結果が起きる</h2><p class="deck">幕は通路を切り替え、回り舞台は群れを分け、蛇腹橋は重さを跳躍へ変えます。琥珀色の同心円は射撃できる箇所、青い描線は相棒が作る足場です。</p>{figure('02-gimmick-settings.png','舞台装置6種の外観と作動前後。仮面門、幕、回り舞台、蛇腹橋、照明、観覧車。')}<p class="note">回り舞台の大砲は演目用の補助装置。主人公も群れも同じ射線を通るため、回転の方向と通過時刻を選びます。現在のハンマーを継続する場合も、この出口の危険として配置できます。</p></section>
<section id="cast"><p class="label">03 / THE PARADE CAST</p><h2>敵も舞台を動かす</h2><p class="deck">既存の小鬼を残し、四つの異なるシルエットと行動を追加する案です。追跡に加えて、群れの指揮、高所の妨害、重りの投下、照明による変身を持たせます。</p>{figure('03-enemy-modelsheet.png','ぜんまい小鬼、鼓笛隊長、竹馬の案内役、風船道化、影の人形のモデルシート。')}<div class="cast-grid">{cards}</div></section>
<section id="map"><p class="label">04 / PROPOSED STAGE MAP</p><h2>六つの演目をつないだ拡張案</h2><p class="deck">青は主人公の経路、赤は群れの流れ。上下の通路を設け、射撃、誘導、重さ、照明、乗り移りへと判断を変えていきます。区画を選ぶと二人の操作と救済方法が表示されます。</p>{figure('04-expanded-stage-map.png','偽入口から観覧車の終幕までの6区画。上下の経路と敵の流れを示す拡張マップ。')}<div class="zones" aria-label="区画を選択">{zones}</div><div class="details" aria-live="polite"><h3 id="zone-title">01 / FALSE ENTRANCE</h3><p id="zone-device">下顎が橋になる仮面門</p><div class="detail-grid"><div><b>二人の操作</b><p id="operation">{ZONES[0][3]}</p></div><div><b>予想が変わる瞬間</b><p id="surprise">{ZONES[0][4]}</p></div><div><b>失敗からの救済</b><p id="rescue">{ZONES[0][5]}</p></div></div></div><p class="note">このマップは新しい空間構成の設計案です。実測の当たり判定やジャンプ距離を表す図ではありません。新しい装置と敵の挙動は、プレイ可能な試作で検証する段階です。</p></section>
<section id="current"><p class="label">05 / CURRENT IMPLEMENTATION</p><h2>動画で使った現在の1−9</h2><div class="source-row"><img src="source-frame.png" alt="既存のステージ1−9のゲーム画面" loading="lazy"><div><p>現在は口の門2基、ハンマー2基、崩れる床3枚、昇降床2枚、小鬼72体。下の図は現在のソース座標から作成しています。</p><p class="meta">Source: src/levels/level_parade_data.gd<br>Video: build/promotion/stage-1-9/melos-stage-1-9.mp4</p></div></div>{figure('05-current-stage-map.svg','ソースから作成した現在の1−9の地形、機構、敵72体とゴールの配置図。')}<p class="note">上の生成画4枚は拡張案です。この設定集の制作でゲームのコードと実行用アセットは変更していません。面白さと二人操作時の負荷は、見た目の設定画からは判断できません。</p></section>
</main><footer>4 paintings generated with built-in image_gen. Original PNGs preserved.<br><a href="README.md">詳しい設定と操作案</a> · <a href="prompts.json">全プロンプト</a> · <a href="current-stage-data.json">現在の配置データ</a></footer>
<script>const zones={detail_json};document.querySelectorAll('[data-zone]').forEach(button=>button.addEventListener('click',()=>{{const z=zones[Number(button.dataset.zone)];document.querySelectorAll('[data-zone]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));document.getElementById('zone-title').textContent=z.title;document.getElementById('zone-device').textContent=z.device;for(const key of ['operation','surprise','rescue'])document.getElementById(key).textContent=z[key];}}));</script>
</body></html>'''


def main():
    for name in ('01-world-imageboard.png', '02-gimmick-settings.png', '03-enemy-modelsheet.png', '04-expanded-stage-map.png', 'README.md', 'prompts.json'):
        if not (OUT / name).is_file():
            raise FileNotFoundError(name)
    geometry = read_geometry()
    (OUT / 'current-stage-data.json').write_text(json.dumps(geometry, ensure_ascii=False, indent=2), encoding='utf-8')
    (OUT / '05-current-stage-map.svg').write_text(current_map(geometry), encoding='utf-8')
    shutil.copy2(ROOT / 'assets/menu/card_1_9.png', OUT / 'source-frame.png')
    (OUT / 'index.html').write_text(build_html(), encoding='utf-8')
    EXPORT.mkdir(parents=True, exist_ok=True)
    files = [p for p in OUT.iterdir() if p.is_file() and p.suffix != '.import']
    for path in files:
        shutil.copy2(path, EXPORT / path.name)
    print(json.dumps({'sheets': 4, 'source_grounds': len(geometry['ground']),
                      'source_machines': len(geometry['gimmicks']),
                      'source_enemies': sum(len(w) for w in geometry['enemy_waves']),
                      'files': len(files), 'viewer': str(EXPORT / 'index.html')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
