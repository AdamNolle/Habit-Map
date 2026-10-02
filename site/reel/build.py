"""Build an honest Habit Map motion preview from source-owned component evidence."""

import bpy
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SNAP = REPO / "Packages/HabitMapCore/Tests/HabitMapCoreTests/__Snapshots__"
INK = (0.946, 0.941, 0.918, 1)
MUTED = (0.53, 0.58, 0.54, 1)
GREEN = (0.239, 1.0, 0.498, 1)
DARK = (0.039, 0.047, 0.043, 1)
PANEL = (0.062, 0.098, 0.070, 1)
LINE = (0.16, 0.25, 0.18, 1)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for block in bpy.data.materials:
    bpy.data.materials.remove(block)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 16
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 1020
scene.render.image_settings.color_mode = "RGB"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.world.color = DARK[:3]

font_paths = {
    "sans": Path("C:/Windows/Fonts/segoeui.ttf"),
    "bold": Path("C:/Windows/Fonts/segoeuib.ttf"),
    "serif": Path("C:/Windows/Fonts/georgiai.ttf"),
    "mono": Path("C:/Windows/Fonts/consola.ttf"),
}
fonts = {name: bpy.data.fonts.load(str(path)) for name, path in font_paths.items() if path.exists()}


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    glow = nodes.new("ShaderNodeEmission")
    glow.inputs["Color"].default_value = color
    glow.inputs["Strength"].default_value = 1
    mat.node_tree.links.new(glow.outputs[0], out.inputs["Surface"])
    return mat, glow


def rect(name, x, y, w, h, color, z=0):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([(-w/2,-h/2,0),(w/2,-h/2,0),(w/2,h/2,0),(-w/2,h/2,0)], [], [(0,1,2,3)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = (x,y,z)
    obj.data.materials.append(material(name+" material", color)[0])
    return obj


def text(name, body, x, y, size, color=INK, font="sans", spacing=1.0, z=.25):
    curve = bpy.data.curves.new(name, type="FONT")
    curve.body = body
    curve.size = size
    curve.space_character = spacing
    curve.space_line = 1.0
    if font in fonts:
        curve.font = fonts[font]
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.location = (x,y,z)
    obj.data.materials.append(material(name+" material", color)[0])
    return obj


def picture(name, path, x, y, w, h):
    obj = rect(name, x, y, w, h, INK, .22)
    mat = bpy.data.materials.new(name+" image material")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    image_node = nodes.new("ShaderNodeTexImage")
    image_node.image = bpy.data.images.load(str(path), check_existing=True)
    image_node.image.filepath = bpy.path.relpath(str(path), start=str(HERE))
    emission = nodes.new("ShaderNodeEmission")
    output = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(image_node.outputs["Color"], emission.inputs["Color"])
    mat.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    uv = obj.data.uv_layers.new(name="UVMap")
    for loop in obj.data.loops:
        vertex = obj.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (vertex.x / w + .5, vertex.y / h + .5)
    return obj


def label(x, number, text_body):
    rect("chapter line", x, 6.9, 26.6, .016, LINE, .12)
    text("issue", f"{number}  /  {text_body}", x-13.3, 7.18, .2, GREEN, "mono", 1.13)
    text("preview label", "PRODUCT PREVIEW  •  ILLUSTRATIVE VISUALS", x-13.3, -7.75, .16, MUTED, "mono")


def key(obj, frame, location=None, scale=None):
    if location is not None:
        obj.location = location
        obj.keyframe_insert(data_path="location", frame=frame)
    if scale is not None:
        obj.scale = scale
        obj.keyframe_insert(data_path="scale", frame=frame)


# Every shot shares the same spatial track. The moving camera travels along the atlas.
centers = [0, 38, 76, 114, 152]
rect("full dark field", 76, 0, 190, 20, DARK, -3)

# 0–4s: mark and title.
x = centers[0]
label(x, "00", "AN ATLAS OF SMALL DAYS")
for i,(dx,dy) in enumerate([(-12,3.5),(-10.95,3.5),(-12,2.45),(-10.95,2.45)]):
    cell = rect("four-cell brand mark", x+dx, dy, .86, .86, GREEN if i in (0,3) else LINE, .3)
    key(cell, 1+i*5, scale=(.1,.1,.1))
    key(cell, 26+i*5, scale=(1,1,1))
text("brand title", "HABIT MAP", x-12.9, -.1, 2.13, INK, "bold", 1.05)
text("brand sub", "A GENTLER RECORD OF SHOWING UP", x-12.7, -1.45, .33, GREEN, "mono", 1.05)
rect("title line", x-12.7, -2.05, 25.3, .025, LINE, .2)
text("opening notice", "IN DEVELOPMENT  /  NO APP FOOTAGE IN THIS PREVIEW", x-12.7, -2.68, .21, MUTED, "mono")

# 4–9s: the idea. The staggered cells are visual language, not simulated app UI.
x = centers[1]
label(x, "01", "MAKE ROOM FOR RETURN")
text("return first line", "Make room", x-13.3, 2.5, 2.18, INK, "sans")
text("return second line", "for return.", x-13.2, .0, 2.27, GREEN, "serif")
text("return caption", "Mark a day. Find a rhythm. Come back when you can.", x-13.2, -1.6, .42, MUTED)
for col in range(13):
    for row in range(3):
        dx = -13.2 + col*2.12
        dy = -4.15 - row*.77
        color = GREEN if (col+row*3)%7==0 else PANEL if (col+row)%3 else LINE
        rect("habit path cell", x+dx, dy, 1.72, .52, color, .2)

# 9–18s: one measured field of days; green arrivals light in sequence.
x = centers[2]
label(x, "02", "THE LONGER VIEW")
text("atlas title", "Today becomes", x-13.2, 4.3, 1.45, INK)
text("atlas title serif", "an atlas.", x-13.1, 2.6, 1.92, GREEN, "serif")
text("atlas details", "PAGES  /  DAY DETAIL  /  CALENDAR HEATMAP", x-13.1, 1.65, .26, MUTED, "mono")
rect("atlas stage", x+2.6, -2.15, 31.2, 8.1, PANEL, .06)
for col in range(23):
    for row in range(7):
        px = x-12.35 + col*1.36
        py = -.0 - row*.71
        mat, node = material("day glow", LINE)
        obj = rect("atlas day", px, py, 1.05, .51, LINE, .25)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        if (col*7+row)%5 != 0:
            onset = 285 + ((col*13 + row*17) % 205)
            node.inputs["Color"].default_value = LINE
            node.inputs["Color"].keyframe_insert(data_path="default_value", frame=onset-1)
            node.inputs["Color"].default_value = GREEN if (col+row)%9==0 else (0.12,.43,.23,1)
            node.inputs["Color"].keyframe_insert(data_path="default_value", frame=onset+7)
text("atlas honesty", "ILLUSTRATIVE CALENDAR PATTERN  /  NATIVE COMPONENT IMPLEMENTED IN APP SOURCE", x-12.9, -6.45, .18, MUTED, "mono")

# 18–26s: source-owned native component snapshots with sample data labels.
x = centers[3]
label(x, "03", "INSIGHT / SOURCE EVIDENCE")
text("insight title", "Notice the", x-13.2, 4.7, 1.55, INK)
text("insight title accent", "patterns.", x-13.1, 2.75, 1.95, GREEN, "serif")
text("insight context", "Native UI component snapshots from the app's test suite.", x-13.1, 1.55, .36, MUTED)
rect("snapshot frame", x, -2.4, 27.2, 5.4, LINE, .08)
rect("snapshot back", x, -2.4, 27.13, 5.33, DARK, .11)
picture("insight snapshot", SNAP / "EditorialInsightSnapshotTests/test_win.1.png", x-3.4, -2.15, 18.5, 3.25)
picture("widget snapshot", SNAP / "HabitWidgetViewSnapshotTests/test_compact_allDoneToday.1.png", x+10.4, -2.0, 4.4, 4.4)
text("snapshot honesty", "EXAMPLE TEST DATA  •  NOT RECORDED APP INTERACTION", x-12.9, -6.1, .22, GREEN, "mono")

# 26–34s: release-honest close, deliberately quiet.
x = centers[4]
rect("final green field", x, 0, 36, 18.5, GREEN, -.2)
rect("final line", x, 6.95, 27, .025, (0.07,.45,.18,1), .1)
text("final issue", "04  /  KEEP THE DOOR OPEN", x-13.3, 7.2, .22, (0.03,.24,.10,1), "mono")
text("final first", "The next day", x-13.3, 2.1, 2.16, (0.035,.14,.07,1), "sans")
text("final second", "is yours.", x-13.3, -.45, 2.5, INK, "serif")
text("final action", "FOLLOW DEVELOPMENT  ↗  GITHUB.COM/ADAMNOLLE/HABIT-MAP", x-13.1, -3.55, .27, (0.03,.24,.10,1), "mono")
text("final qualifier", "ILLUSTRATIVE PRODUCT PREVIEW  /  APP FOOTAGE TO FOLLOW", x-13.1, -7.75, .16, (0.03,.24,.10,1), "mono")

# Orthographic camera travelling between established frames.
bpy.ops.object.camera_add(location=(-.7, 0, 26))
camera = bpy.context.object
camera.name = "Atlas dolly camera"
camera.data.type = "ORTHO"
camera.data.ortho_scale = 32
scene.camera = camera
track = [(1,-.7),(85,0),(120,37.8),(255,38.2),(282,75.6),
         (520,76.4),(550,113.8),(750,114.2),(785,151.6),(1020,152.2)]
for frame, xx in track:
    camera.location = (xx, 0, 26)
    camera.keyframe_insert(data_path="location", frame=frame)
score = HERE / "score.wav"
if score.exists():
    editor = scene.sequence_editor_create()
    editor.strips.new_sound("Original score", str(score), channel=1, frame_start=1)

scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "habit-map-preview.blend"))

args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
if "--still" in args:
    frame = int(args[args.index("--still")+1])
    scene.frame_set(frame)
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(HERE / f"frame-{frame:04}.png")
    bpy.ops.render.render(write_still=True)
