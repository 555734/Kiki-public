"""Build the expanded setting book; keep source sprites and AI PNGs intact."""
from pathlib import Path
import hashlib
import html
import json
import shutil
import build_parade_artbook as original_book

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/promotion/parade-artbook-v2'
EXPORT = ROOT / 'build/promotion/stage-1-9/artbook-v2'
MACHINES = [
    ('MASK GATE', '仮面門', '頬の留め金を撃つと下顎が橋になる。敵も橋を渡るので、開く時刻を選ぶ。'),
    ('CURTAIN LIFT', '幕と対重', '幕と対重が反対に動き、上下の通路を切り替える。相棒が落下先を支える。'),
    ('PARADE TURNTABLE', '回り舞台', 'クラッチを撃つと群れの出口が変わる。鼓笛隊長の跳躍で上の通路にも敵が来る。'),
    ('ACCORDION BRIDGE', '蛇腹橋', '敵の重みを貯め、ばねを解放して主人公ごと跳ばす。圧縮量と着地点を選ぶ。'),
    ('FOLLOW SPOT', '追尾照明', '照明の向きを変えると、人形が敵と固い小道具の姿を切り替える。'),
    ('SKY WHEEL', '空の観覧車', '反対側のゴンドラに乗る群れが釣り合いを変える。ブレーキと渡り足場を組み合わせる。'),
    ('SCENERY RAILS', '舞台レール', '背景の壁が横へ動き、窓や足場の位置が変わる。上に乗るか、開いた下の通路へ進む。'),
    ('TRAPDOOR ROW', '連続開閉床', '敵が踏むと隣の床へ開閉が連鎖する。順番を読んで跳び、下の受け足場で救う。'),
    ('STUNT CANNON', '演目用大砲', '射出角を低い通路と高い弧へ切り替える。主人公と敵の射出先を分ける。'),
    ('PROP CONVEYOR', '小道具搬送ベルト', '回転方向を変え、箱と敵を落とし穴または対重の皿へ運ぶ。'),
    ('CONFETTI VENT', '紙吹雪の送風口', '噴流が空中の主人公と敵を押し上げる。描いた壁で風向きを曲げる。'),
    ('PENDULUM BELL', '振り子の鐘', '振り子が群れを別の高さへ押す。留め金を撃って、通過する時刻に位相を合わせる。'),
    ('MIRROR SPOT', '鏡の照明', 'スクリーンへ主人公の影を投影し、敵を誘導する。実体の主人公は別の通路を進む。'),
    ('PAPER MOON', '紙の月', '吊られた三日月の小道具を下ろし、曲線の橋として渡る。'),
    ('BALANCING BALCONY', '釣り合いバルコニー', '片端へ群れを乗せると、反対側の主人公が持ち上がる。二つの角度で固定できる。'),
    ('MAGNETIC PROP HOIST', '磁力の吊り装置', '金属の敵を持ち上げ、群れを対重の皿へ放す。主人公は磁力の対象にならない。'),
    ('FIREWORK RACK', '舞台花火', '予告灯と導火線に沿って三段階で作動する。次の花火までに逃げ道を描く。'),
    ('BREAKAWAY SCENERY', '壊れる書き割り', '猟犬を誘導して偽の壁へ突進させると、裏の階段が現れる。'),
]
ENEMIES = [
    ('WIND-UP GREMLIN', 'ぜんまい小鬼', '既存の小鬼。拡張案では群れの重さが装置を動かす。'),
    ('DRUM MAJOR', '鼓笛隊長', 'ばちの振り上げを予告に、小鬼を一斉に跳ばせる。'),
    ('STILT USHER', '竹馬の案内役', '上の通路を掃く。膝を撃つと長い脚が一時的な斜面になる。'),
    ('BALLOON HARLEQUIN', '風船道化', '風船のひもを撃つと重りが落ちる。群れと橋へ作用する。'),
    ('SHADOW MARIONETTE', '影の人形', '照明の中で動く敵になり、暗いときは固い小道具になる。'),
    ('PROP MIMIC', '小道具の擬態箱', '搬送できる箱に紛れ、出口で蓋を開いて進路を塞ぐ。'),
    ('RIGGING SPIDER', '吊り索の蜘蛛', '舞台の支点間へ索を張り、連続開閉床の留め金を動かす。'),
    ('CANNON IMP', '砲台小鬼', 'ぜんまいの溜めを予告に低い弾を放ち、群れを搬送ベルトへ押し出す。'),
    ('RIBBON ACROBAT', '吊り布の軽業師', '二本の布で上下の通路を横断する。結び目を撃つと軌道が逆になる。'),
    ('CLOCKWORK HOUND', 'ぜんまい猟犬', '予告して突進し、書き割りを壊す。追跡を新しい通路の発見へ利用する。'),
    ('MIRROR TWINS', '鏡の双子', '鏡で動きが連動する二体一組。鏡を壊すと同期が外れる。種類数では一種類と数える。'),
    ('STAGE MANAGER', '舞台監督', 'カチンコを大きく振り上げて予告し、幕・照明・吊り装置の状態を切り替える。'),
]
ZONES = [
    ('FALSE ENTRANCE', '偽入口', [1, 7, 8], [1, 6], '主人公が口を避け、相棒が橋を開く。動く壁の上を通るか、下の床を順に跳ぶ。', '運べる箱が出口で敵に変わる。描いた上の足場へ逃げ、群れを先に流す。'),
    ('BACKSTAGE', '舞台裏', [2, 12, 16], [3, 7], '対重と鐘の動きを合わせ、高い通路へ移る。磁力で群れを別の皿へ運ぶ。', '竹馬の敵と吊り索が上下の安全を変える。膝を崩して斜面を作り、下の足場で受ける。'),
    ('PARADE CROSSING', 'パレードの交差点', [3, 9, 10], [1, 2, 8], '回り舞台で出口を選び、大砲の角度と搬送方向を切り替える。', '鼓笛隊長が群れを一斉に跳ばせる。砲台小鬼の予告を見て、射線の外へ足場を描く。'),
    ('ACCORDION GAP', '蛇腹の谷', [4, 11, 15], [1, 4, 9], '重さを貯めて射出し、風とバルコニーを使って次の高さへ渡る。', '風船の重りと軽業師が飛ぶ軌道を変える。解放前に受け足場を用意する。'),
    ('SPOTLIGHT GALLERY', '照明回廊', [5, 13, 18], [5, 10, 11], '照明で敵を止め、鏡の影へ群れを誘導する。猟犬に書き割りを壊させて階段を出す。', '足場にした小道具が動き出し、双子が通路を挟む。照明の切り替えと別の足場で逃げる。'),
    ('SKY WHEEL FINALE', '観覧車の終幕', [6, 14, 17], [1, 12], '月の橋で観覧車へ乗り、対岸の群れを重りにする。ブレーキと描画で本物の旗へ渡る。', '舞台監督が予告後に装置を切り替える。花火の順番を読み、停車したゴンドラで立て直す。'),
]
ARTS = [
    ('01-world-imageboard.png', '既存のLiraに修正した劇場都市の世界観ボード'),
    ('02-machines-core.png', '基本ギミック01-06とLiraの操作'),
    ('03-machines-backstage.png', '舞台裏のギミック07-12'),
    ('04-machines-illusions.png', '錯覚と連鎖を扱うギミック13-18'),
    ('05-cast-core.png', '敵01-05のモデルシート'),
    ('06-cast-backstage.png', '敵06-09のモデルシート'),
    ('07-cast-elites.png', '敵10-12のモデルシート'),
    ('08-expanded-stage-map.png', '主人公をLiraに統一した6区画の拡張マップ'),
]
POSES = [('idle', 'IDLE'), ('run', 'RUN'), ('jump', 'JUMP'), ('fall', 'FALL'),
         ('land', 'LAND'), ('dash', 'DASH'), ('reach', 'REACH'), ('cheer', 'CHEER')]


def art(index):
    name, label = ARTS[index]
    return f'<a class="art" href="{name}" target="_blank" rel="noopener"><img src="{name}" alt="{label}"></a><p class="caption">画像を選ぶと原寸で開きます</p>'


def entries(data, first, stop, prefix):
    return '<div class="catalogue">' + ''.join(
        f'<article id="{prefix}{i+1:02d}"><small>{prefix}{i+1:02d}</small><h3>{a}</h3><b>{b}</b><p>{html.escape(c)}</p></article>'
        for i, (a, b, c) in enumerate(data) if first <= i < stop) + '</div>'


def build_html():
    prior = (ROOT / 'docs/promotion/parade-artbook-v1/index.html').read_text(encoding='utf-8')
    css = prior.split('<style>')[1].split('</style>')[0]
    css += '.hero-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.hero-pose{background:#efe4cf;border:1px solid #dac5a0;text-align:center;padding:12px}.hero-pose img{width:143px;height:143px;object-fit:contain;display:block;margin:auto}.hero-pose span{font-size:12px;letter-spacing:.12em}.identity{display:flex;gap:24px;align-items:center;padding:16px;background:#efe4cf;margin-bottom:22px}.identity img{width:120px;image-rendering:auto}.identity p{margin:0}.catalogue{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin:20px 0 38px}.catalogue article{border-top:2px solid var(--gold);padding:14px 8px}.catalogue small{color:var(--coral)}.catalogue b{font-size:13px}.catalogue p{font-size:13px;margin:8px 0}.sheet-title{margin-top:40px;font-size:23px}.combination{display:grid;grid-template-columns:1fr 1fr;gap:24px}.combination p{font-size:14px}.combination b{color:var(--coral)}@media(max-width:850px){.hero-grid{grid-template-columns:repeat(2,1fr)}.catalogue{grid-template-columns:repeat(2,1fr)}.combination{grid-template-columns:1fr}.identity{align-items:flex-start}.identity img{width:75px}}@media(max-width:480px){.catalogue{grid-template-columns:1fr}}'
    css += '@media(max-width:480px){.identity{display:grid;grid-template-columns:64px minmax(0,1fr);gap:12px}.identity img{width:64px}.identity p{grid-column:2;grid-row:1 / span 2}.identity img:last-child{grid-column:1;grid-row:2}.hero-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.hero-pose{min-width:0;padding:8px}.hero-pose img{width:100%;max-width:143px;height:auto;aspect-ratio:1;object-fit:contain}.zones{grid-template-columns:1fr}.catalogue article{min-width:0}.catalogue h3{overflow-wrap:anywhere}h2{font-size:28px}}'
    poses = ''.join(f'<div class="hero-pose"><img src="references/runner_{name}.png" alt="既存Liraの{label}原本"><span>{label}</span></div>' for name, label in POSES)
    machine_sheets = ''.join(f'<h3 class="sheet-title">{title}</h3>{art(image)}{entries(MACHINES,start,stop,"A")}'
                            for title, image, start, stop in [('01–06 / 基本装置',1,0,6),('07–12 / 移動とタイミング',2,6,12),('13–18 / 錯覚と連鎖',3,12,18)])
    enemy_sheets = ''.join(f'<h3 class="sheet-title">{title}</h3>{art(image)}{entries(ENEMIES,start,stop,"E")}'
                          for title, image, start, stop in [('01–05 / パレードの出演者',4,0,5),('06–09 / 舞台裏の敵',5,5,9),('10–12 / 猟犬・双子・舞台監督',6,9,12)])
    buttons = ''.join(f'<button type="button" class="zone" data-zone="{i}" aria-pressed="{"true" if i==0 else "false"}"><b>0{i+1}</b><span>{a}<small>{b}</small></span></button>' for i,(a,b,*_) in enumerate(ZONES))
    details = [{'title':f'0{i+1} / {a}', 'machines':' / '.join(f'A{n:02d} {MACHINES[n-1][1]}' for n in ms),
                'enemies':' / '.join(f'E{n:02d} {ENEMIES[n-1][1]}' for n in es), 'operation':op,'recovery':recovery}
               for i,(a,b,ms,es,op,recovery) in enumerate(ZONES)]
    first = details[0]
    return f'''<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>THE TRICKSTER PARADE · Design book 02</title><style>{css}</style></head><body>
<header><div class="eyebrow">MELOS GAME · DESIGN BOOK 02 · 2026.10.10</div><h1>THE TRICKSTER<br>PARADE</h1><p class="intro">主人公は元のLiraのまま。劇場の設定を、18種のギミックと12種の敵へ広げました。装置を動かす、群れを運ぶ、敵の行動を利用する、という異なる突破方法を組み合わせます。</p><p class="meta">Stage 1−9 · Inoue &amp; Sasabe · Expanded design exploration</p></header>
<nav aria-label="設定集のページ"><div><a href="#hero">00 元の主人公</a><a href="#world">01 世界観</a><a href="#machines">02 ギミック18種</a><a href="#enemies">03 敵12種</a><a href="#map">04 拡張マップ</a><a href="#current">05 現在の配置</a></div></nav><main>
<section id="hero"><p class="label">00 / CANONICAL CHARACTER</p><h2>既存の主人公Lira</h2><div class="identity"><img src="references/portrait_lira.png" alt="既存Liraの肖像原本"><p>茶色の髪、赤いマフラー、白い袖と青い服、茶色の手袋とブーツ。下の8ポーズは現在のゲームが使うPNGの原本です。生成画でもこの顔・髪・服装を引き継ぎます。</p><img src="references/portrait_orion.png" alt="既存の相棒Orionの肖像原本"></div><div class="hero-grid">{poses}</div><p class="meta">Source: assets/characters/runner_*.png · src/render/manifests/common.gd。右の青いフードの相棒は既存のOrion。</p></section>
<section id="world"><p class="label">01 / WORLD IMAGEBOARD</p><h2>空に浮かぶからくり劇場</h2><p>動画の美術を継承し、主人公の姿を元のLiraに修正しました。珊瑚色の木、青緑の金属、真鍮、仮面とぜんまいが共通の素材です。</p>{art(0)}</section>
<section id="machines"><p class="label">02 / 18 STAGE MACHINES</p><h2>三つの資料で装置を見比べる</h2><p>基本装置6種、移動とタイミング6種、錯覚と連鎖6種。琥珀色の同心円は射撃できる場所、青い描線は相棒の足場です。操作の結果は敵にも主人公にも作用します。</p>{machine_sheets}</section>
<section id="enemies"><p class="label">03 / 12 ENEMY TYPES</p><h2>敵ごとに違う仕事がある</h2><p>追跡する群れ、指揮役、高所の妨害役、装置を動かす舞台係、通路を破壊する敵、演目を切り替える舞台監督。姿と行動をセットで示します。鏡の双子は二体一組で一種類です。</p>{enemy_sheets}</section>
<section id="map"><p class="label">04 / EXPANDED STAGE MAP</p><h2>六つの区画に組み合わせる</h2><p>各区画の主役装置1つに補助装置2つを組み合わせた空間案です。マップの青い経路を走る人物は元のLira。種類の正確な対応は下の区画選択で確認できます。</p>{art(7)}<div class="zones">{buttons}</div><div class="details" aria-live="polite"><h3 id="zone-title">{first['title']}</h3><p id="zone-machines">{first['machines']}</p><p id="zone-enemies">{first['enemies']}</p><div class="combination"><div><b>二人の操作</b><p id="zone-operation">{first['operation']}</p></div><div><b>意外性と救済</b><p id="zone-recovery">{first['recovery']}</p></div></div></div><p class="note">拡張マップは空間構成のイメージです。全18種を一度に操作させる想定ではなく、区画ごとに組み合わせます。新しい挙動は設計案で、ゲームへの実装は次の段階です。</p></section>
<section id="current"><p class="label">05 / CURRENT IMPLEMENTATION</p><h2>動画で使用した現在の配置</h2><p>現在の1−9は口の門2基、ハンマー2基、崩れる床3枚、昇降床2枚、小鬼72体。下の図は現在のソースの座標から作成したものです。</p><a class="art" href="09-current-stage-map.svg" target="_blank" rel="noopener"><img src="09-current-stage-map.svg" alt="ソースから作成した現在の1−9の配置"></a><p class="meta">Source: src/levels/level_parade_data.gd。機構の記号は危険判定の形ではなく位置を示します。</p></section>
</main><footer>Built-in image_gen · Original game sprites and generated PNGs preserved.<br><a href="README.md">設定書</a> · <a href="catalogue.json">全種類と区画の対応</a> · <a href="prompts.json">全プロンプト</a> · <a href="validation.json">保存と表示の確認</a></footer>
<script>const zoneData={json.dumps(details,ensure_ascii=False)};document.querySelectorAll('[data-zone]').forEach(button=>button.addEventListener('click',()=>{{const z=zoneData[Number(button.dataset.zone)];document.querySelectorAll('[data-zone]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));for(const key of ['title','machines','enemies','operation','recovery'])document.getElementById('zone-'+key).textContent=z[key];}}));</script></body></html>'''


def build_readme():
    text = ['# THE TRICKSTER PARADE — Design book 02', '', '2026-10-10 · MELOS GAME · Inoue & Sasabe', '',
            '主人公を既存のLiraへ統一。ギミックを6種から18種、敵を5種から12種へ拡張した設定集。',
            'index.htmlで原寸画像、主人公の原本8ポーズ、各区画の操作と救済を確認できる。', '',
            '## 主人公の参照', '', 'assets/characters/runner_*.pngの原本8ポーズと既存肖像をreferences/へ複製した。',
            '茶色の髪、赤いマフラー、白い袖と青い服、茶色の手袋とブーツを保つ。',
            '世界観・基本ギミック・拡張マップの主人公をこの姿へ修正した。', '', '## ギミック18種', '',
            '| ID | 名前 | 挙動・判断 |', '| --- | --- | --- |']
    text += [f'| A{i+1:02d} | {a} / {b} | {c} |' for i,(a,b,c) in enumerate(MACHINES)]
    text += ['', '## 敵12種', '', '| ID | 名前 | 挙動・役割 |', '| --- | --- | --- |']
    text += [f'| E{i+1:02d} | {a} / {b} | {c} |' for i,(a,b,c) in enumerate(ENEMIES)]
    text += ['', '## 6区画の組み合わせ', '', '| 区画 | 装置 | 敵 | 二人の操作 | 意外性・救済 |', '| --- | --- | --- | --- | --- |']
    text += [f'| {i+1:02d} {a} / {b} | '+', '.join(f'A{n:02d}' for n in ms)+' | '+', '.join(f'E{n:02d}' for n in es)+f' | {op} | {recovery} |' for i,(a,b,ms,es,op,recovery) in enumerate(ZONES)]
    text += ['', '## 範囲と制作', '',
             '今回の成果は設定資料。ゲームコード、主人公の実行用アセット、既存の動画は変更していない。',
             '新しい挙動の面白さと二人操作の負荷は、プレイ可能な試作で確かめる段階。',
             'マップは空間構成のイメージであり、当たり判定やジャンプ距離の実測図ではない。',
             '全種類の正確なIDと対応はcatalogue.jsonに記載。マップの小さな種類番号は読みやすさのため外した。',
             '', '7枚の更新・追加画は組み込みimage_genで生成。敵01-05の1枚は前版の原本を継承した。',
             '生成PNGの画素をPythonで編集していない。全プロンプトと参照画像はprompts.json。',
             '公開origin/mainを取得し、HEADとの一致を確認した。基準コミットはff1607e1274640c09fb88399d9c79a36b798b67d。',
             'tools/promotion/build_parade_artbook_v2.pyで閲覧ページ・種類表・現在の配置図を再生成する。',
             '保存先: docs/promotion/parade-artbook-v2/ と build/promotion/stage-1-9/artbook-v2/。', '']
    return '\n'.join(text)


def main():
    assert len(MACHINES) == 18 and len(ENEMIES) == 12
    assert sorted(n for _,_,ms,_,_,_ in ZONES for n in ms) == list(range(1,19))
    assert set(n for _,_,_,es,_,_ in ZONES for n in es) == set(range(1,13))
    for filename, _ in ARTS:
        if not (OUT / filename).is_file():
            raise FileNotFoundError(filename)
    refs = OUT / 'references'
    refs.mkdir(exist_ok=True)
    sources = [(ROOT / f'assets/characters/runner_{name}.png', refs / f'runner_{name}.png') for name,_ in POSES]
    sources += [(ROOT / f'assets/ui/portrait_{name}.png',refs / f'portrait_{name}.png') for name in ('lira','orion')]
    hashes = []
    for source, target in sources:
        shutil.copy2(source,target)
        sha = hashlib.sha256(source.read_bytes()).hexdigest()
        assert hashlib.sha256(target.read_bytes()).hexdigest() == sha
        hashes.append({'source':str(source.relative_to(ROOT)).replace('\\','/'), 'copy':str(target.relative_to(OUT)).replace('\\','/'), 'sha256':sha})
    catalogue = {'machines':[{'id':f'A{i+1:02d}','name':a,'japanese':b,'behavior':c} for i,(a,b,c) in enumerate(MACHINES)],
                 'enemies':[{'id':f'E{i+1:02d}','name':a,'japanese':b,'behavior':c} for i,(a,b,c) in enumerate(ENEMIES)],
                 'zones':[{'number':i+1,'name':a,'japanese':b,'machines':ms,'enemies':es,'operation':op,'recovery':rec} for i,(a,b,ms,es,op,rec) in enumerate(ZONES)]}
    geometry=original_book.read_geometry()
    (OUT/'09-current-stage-map.svg').write_text(original_book.current_map(geometry),encoding='utf-8')
    (OUT/'current-stage-data.json').write_text(json.dumps(geometry,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'hero-reference-hashes.json').write_text(json.dumps(hashes,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'catalogue.json').write_text(json.dumps(catalogue,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'README.md').write_text(build_readme(),encoding='utf-8')
    (OUT/'index.html').write_text(build_html(),encoding='utf-8')
    for path in OUT.rglob('*'):
        if path.is_file() and path.suffix != '.import':
            target=EXPORT/path.relative_to(OUT)
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(path,target)
    print(json.dumps({'paintings':len(ARTS),'hero_originals':8,'machines':len(MACHINES),'enemy_types':len(ENEMIES),'zones':len(ZONES),'viewer':str(EXPORT/'index.html')},ensure_ascii=False))


if __name__=='__main__':
    main()
