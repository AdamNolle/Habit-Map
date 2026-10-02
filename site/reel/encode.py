"""Assemble deterministic motion frames and original score in Blender VSE."""
import bpy
from pathlib import Path

here = Path(__file__).resolve().parent
frames = here / "frames"
first = frames / "frame-0001.jpg"
if not first.is_file():
    raise FileNotFoundError(first)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 1020
scene.render.use_sequencer = True
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
editor = scene.sequence_editor_create()
images = editor.strips.new_image("Authored motion frames", str(first), channel=1, frame_start=1)
for i in range(2, 1021):
    images.elements.append(f"frame-{i:04}.jpg")
images.frame_final_duration = 1020
images.directory = "//frames/"

score = here / "score.wav"
if score.is_file():
    sound = editor.strips.new_sound("Original synthesized score", str(score), channel=2, frame_start=1)
    sound.frame_final_duration = 1020
    sound.sound.filepath = "//score.wav"

scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(here / "frames")
bpy.ops.wm.save_as_mainfile(filepath=str(here / "habit-map-edit.blend"))
