use std::{collections::BTreeMap, env, fmt::Write, fs, path::Path};
use ttf_parser::{Face, GlyphId, OutlineBuilder};

#[derive(Default)]
struct Outline(String);
impl OutlineBuilder for Outline {
    fn move_to(&mut self, x: f32, y: f32) {
        write!(self.0, "M{x:.3} {:.3}", -y).unwrap();
    }
    fn line_to(&mut self, x: f32, y: f32) {
        write!(self.0, "L{x:.3} {:.3}", -y).unwrap();
    }
    fn quad_to(&mut self, x1: f32, y1: f32, x: f32, y: f32) {
        write!(self.0, "Q{x1:.3} {:.3} {x:.3} {:.3}", -y1, -y).unwrap();
    }
    fn curve_to(&mut self, x1: f32, y1: f32, x2: f32, y2: f32, x: f32, y: f32) {
        write!(
            self.0,
            "C{x1:.3} {:.3} {x2:.3} {:.3} {x:.3} {:.3}",
            -y1, -y2, -y
        )
        .unwrap();
    }
    fn close(&mut self) {
        self.0.push('Z');
    }
}

fn export(face: &Face, glyph: GlyphId, path: &Path) -> bool {
    let mut outline = Outline::default();
    let Some(bounds) = face.outline_glyph(glyph, &mut outline) else {
        return false;
    };
    let width = f32::from(bounds.x_max) - f32::from(bounds.x_min);
    let height = f32::from(bounds.y_max) - f32::from(bounds.y_min);
    if width <= 0.0 || height <= 0.0 || outline.0.is_empty() {
        return false;
    }
    let pad = width.max(height) * 0.035;
    let svg = format!(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"{} {} {} {}\"><path fill=\"#fff\" fill-rule=\"nonzero\" d=\"{}\"/></svg>\n",
        f32::from(bounds.x_min) - pad, -f32::from(bounds.y_max) - pad,
        width + pad * 2.0, height + pad * 2.0, outline.0
    );
    let temporary = path.with_extension("svg.new");
    fs::write(&temporary, svg).expect("write SVG");
    fs::rename(temporary, path).expect("install SVG");
    true
}

fn safe_name(name: &str) -> bool {
    !name.is_empty()
        && !name.starts_with('.')
        && name
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || b"._-".contains(&c))
}

fn main() {
    let args: Vec<_> = env::args().collect();
    assert_eq!(
        args.len(),
        4,
        "Usage: p3r-symbol-export FONT NAME_TO_CHARACTER_JSON ICON_THEME_DIRECTORY"
    );
    let data = fs::read(&args[1]).expect("read symbol font");
    let face = Face::parse(&data, 0).expect("parse OpenType font");
    let names: BTreeMap<String, String> =
        serde_json::from_slice(&fs::read(&args[2]).expect("read character map"))
            .expect("parse name-to-character map");
    let root = Path::new(&args[3]);
    let directory = root.join("scalable/status");
    fs::create_dir_all(&directory).expect("create icon directory");
    let mut manifest = BTreeMap::new();
    for id in 0..face.number_of_glyphs() {
        let glyph = GlyphId(id);
        let Some(name) = face.glyph_name(glyph) else {
            continue;
        };
        if !(name.starts_with("uni10") || name.contains(".color")) {
            continue;
        }
        let name = name.replace(".color", "");
        if safe_name(&name) && export(&face, glyph, &directory.join(format!("{name}.svg"))) {
            manifest.insert(name, id);
        }
    }
    // Public symbol names are aliases to glyphs from the user's own font.
    let mut aliases = 0;
    for (name, character) in names {
        if !safe_name(&name) {
            continue;
        }
        let Some(glyph) = character.chars().next().and_then(|c| face.glyph_index(c)) else {
            continue;
        };
        if export(&face, glyph, &directory.join(format!("{name}.svg"))) {
            manifest.insert(name, glyph.0);
            aliases += 1;
        }
    }
    fs::write(
        root.join("symbols.json"),
        serde_json::to_vec_pretty(&manifest).unwrap(),
    )
    .unwrap();
    fs::write(root.join("index.theme"), "[Icon Theme]\nName=SF Symbols\nComment=Locally extracted symbol outlines\nDirectories=scalable/status\n\n[scalable/status]\nSize=32\nMinSize=8\nMaxSize=512\nType=Scalable\nContext=Status\n").unwrap();
    println!(
        "Installed {} SVGs ({} public-name aliases) to {}",
        manifest.len(),
        aliases,
        root.display()
    );
}
