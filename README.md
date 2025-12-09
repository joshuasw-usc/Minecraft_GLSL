# GLSL Minecraft
A GLSL program that replicates Minecraft's scenery.

---

## 📘 Overview
Our project is a Minecraft style procedural generation program. Our goal is to develop a ray-tracing program that mimics Minecraft’s scenery via procedurally generated terrain, custom noise based textures, randomly generated caverns, and camera/user movement.

---

## 📁 File Structure

/project-root
│
├── shader.glsl                # Main shader script  
├── bufferA.glsl               # Buffer for camera position
├── helper.glsl                # Helper method holder
├── noise.png                  # Noise texture for iChannel0
├── WorleyNoise.png            # Noise texture for iChannel0
├── screenshot_progress.png    # Early progress image
└── README.md


---

## 🎨 ShaderToy Setup

### 1. **Image Shader (shader.glsl)**
1. Create or open an *Image* pass in ShaderToy.
2. Paste the contents of `shader.glsl` into the Image shader.
3. Configure the channels:
   - **iChannel0 →** `noise.png`
   - **iChannel1 →** *Buffer A*

### 2. **Common Shader (helper.glsl)**
1. Open the **Common** tab.
2. Paste the contents of `helper.glsl`.

### 3. **Buffer A Shader (bufferA.glsl)**
1. Create or open a **Buffer A** pass.
2. Paste the contents of `bufferA.glsl`.
3. Configure the channels:
   - **iChannel0 →** *Buffer A* (self-reference)
   - **iChannel1 →** *Keyboard*

---

## 🧰 Visual Studio Code Setup

### 1. **Clone or Download the Repository**
1. Clone this repo or download the ZIP.
2. Open the project folder in Visual Studio Code.

### 2. **Install the ShaderToy Extension**
1. Open the Extensions panel in VSCode.
2. Search for:  
   - **ShaderToy**, or  
   - **GLSL ShaderToy Preview**
3. Install the extension.

### 3. **Preview the Shader in VSCode**
1. Open the `shader.glsl` file.
2. Open the **Command Palette** (Ctrl+Shift+P or Cmd+Shift+P).
3. Run:  
   **ShaderToy: GLSL Preview**  
   (Name may vary slightly depending on the extension.)


## 🙌 Credits
- Josh Williams
- Rachel Oh
- Nico Slavonia

---
