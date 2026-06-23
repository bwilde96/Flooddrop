using Godot;
public partial class ShaderTest : SceneTree {
    public override void _Initialize() {
        var shader = ResourceLoader.Load<Shader>("res://assets/crashing_wave.gdshader");
        if (shader == null) {
            GD.Print("SHADER NULL");
        } else {
            GD.Print("SHADER LOADED");
        }
        Quit();
    }
}
