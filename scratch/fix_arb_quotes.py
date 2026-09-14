import json
import glob

arb_files = glob.glob("/Users/Safi_Sahib/safi_academy_app/lib/l10n/*.arb")

for filepath in arb_files:
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    modified = False
    for k, v in list(data.items()):
        if isinstance(v, str) and not k.startswith("@"):
            # Normalize: replace ’ with '' and lone ' with ''
            # First reduce any '''' or '' to single ' then duplicate
            cleaned = v.replace("''", "'").replace("'", "''")
            if cleaned != v:
                data[k] = cleaned
                modified = True
                
    if modified:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Normalized quotes in {filepath}")

print("Quote fix complete.")
