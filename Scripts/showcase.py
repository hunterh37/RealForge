import re, os, sys, subprocess, shutil, glob, hashlib
R = "/Users/hunter/Dev/RealForge"; os.chdir(R)
OUT = "showcase"
def git(*a, binary=False):
    return subprocess.run(["git", *a], capture_output=True, check=False).stdout if binary else subprocess.run(["git", *a], capture_output=True, text=True).stdout
# type -> id, and group per id
t2id, idinfo = {}, {}
for f in glob.glob("Sources/RealLibrary/**/*.swift", recursive=True):
    if "/Scenes/" in f: continue
    src = open(f).read()
    for m in re.finditer(r'struct (\w+)\s*:\s*RealAsset', src):
        i = re.search(r'static let id = "([^"]+)"', src[m.start():])
        s = re.search(r'static let summary = "([^"]*)"', src[m.start():])
        if i:
            t2id[m.group(1)] = i.group(1)
            parts = f.split("/"); idinfo[i.group(1)] = (parts[2], s.group(1) if s else "")
# Props.all for prop-yard
props_src = open("Sources/RealLibrary/Props/Props.swift").read()
prop_ids = [t2id[t] for t in re.findall(r'\b([A-Z]\w+)\.self', props_src) if t in t2id]
species = {"spruce": "spruce-tree", "oak": "oak-tree", "birch": "birch-tree", "maple": "maple-tree", "pine": "scots-pine",
           "beech": "beech-tree", "willow": "willow-tree", "aspen": "aspen-tree", "fir": "fir-tree", "larch": "larch-tree"}
scenes = []
for f in sorted(glob.glob("Sources/RealLibrary/Scenes/*.swift")):
    src = open(f).read()
    m = re.search(r'static let id = "([^"]+)"', src)
    if not m: continue
    sid = m.group(1)
    summ = re.search(r'static let summary = "([^"]*)"', src).group(1)
    author = (re.search(r'static let author = "([^"]*)"', src) or [None, "realityhd"])[1]
    used = []
    for t in re.findall(r'\b([A-Z]\w+)(?:\(|\.self|\.id)', src):
        if t in t2id and t2id[t] not in used: used.append(t2id[t])
    for sp in re.findall(r'Tree\(\.(\w+)\)', src):
        if sp in species and species[sp] not in used: used.append(species[sp])
    if "Props.all" in src: used += [p for p in prop_ids if p not in used]
    scenes.append((sid, summ, author, used))
if os.path.exists(OUT): shutil.rmtree(OUT)
os.makedirs(OUT)
sys.path.insert(0, "Scripts"); from brand import brand
def blob(rev, path): return git("show", f"{rev}:{path}", binary=True) or None
def first_rev(path):
    revs = git("log", "--format=%h", "--", path).split()
    return revs[-1] if revs else None
total = 0
for sid, summ, author, used in scenes:
    path = f"docs/scenes/{sid}.png"
    fpath, frev = (("docs/forest-glade.png", "1fc90f3") if sid == "forest-glade" else (path, first_rev(path)))
    rel, first = blob("v3.0.0", path), blob(frev, fpath) if frev else None
    out = []
    if rel: out.append(("01-release-v3.0.0", rel))
    if first and first != rel: out.append(("02-first-" + frev, first))
    for i, p in enumerate(sorted(glob.glob(f"docs/demo/{sid}*.png"))):
        out.append((f"03-vision-pro-{os.path.basename(p)[:-4]}", open(p, "rb").read()))
    for a in used:
        p = f"docs/assets/{a}.png"
        if os.path.exists(p): out.append((f"04-asset-{a}", open(p, "rb").read()))
    for name, b in out:
        f = f"{OUT}/{sid}--{name}.png"; open(f, "wb").write(b)
        brand(f, f[:-4] + ".jpg"); os.remove(f)
    total += len(out); print(sid, len(out))
print("total", total)
