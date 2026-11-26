# Mi configuración de Neovim y WezTerm

Configuración personal de [AstroNvim](https://github.com/AstroNvim/AstroNvim) v6, más la de
[WezTerm](https://wezterm.org) en la carpeta `wezterm/`. Sirve tal cual en Windows y en Linux.

## Instalación

### 1. Neovim

Clonar este repositorio en la carpeta de configuración de Neovim y abrir `nvim`; los plugins se
instalan solos en el primer arranque.

Windows (PowerShell):

```powershell
git clone https://github.com/samsaga2/nvim-configuration $env:LOCALAPPDATA\nvim
```

Linux:

```shell
git clone https://github.com/samsaga2/nvim-configuration ~/.config/nvim
```

### 2. WezTerm

WezTerm busca su configuración en `~/.wezterm.lua`. Ese archivo es solo un cargador de unas líneas
que apunta a `wezterm/wezterm.lua` de este repositorio; basta con copiarlo una vez.

Windows (PowerShell):

```powershell
Copy-Item $env:LOCALAPPDATA\nvim\wezterm\loader.lua $HOME\.wezterm.lua
```

Linux:

```shell
cp ~/.config/nvim/wezterm/loader.lua ~/.wezterm.lua
```

A partir de ahí, cualquier cambio en `wezterm/wezterm.lua` se aplica al guardar.

## Cosas que dependen de la máquina

- **Versión de Visual Studio para compilar desde Neovim** (solo Windows): `lua/msvc_env.lua`, variable
  `vs_version_range`. En Linux ese módulo no hace nada.
- **Rutas de Visual Studio y del proyecto en WezTerm** (solo Windows): al principio del bloque
  `if is_windows` de `wezterm/wezterm.lua` (`VS2022`, `VS18`, `PROJECT_DIR`).
- **Herramientas externas**: `git`, `ripgrep`, `fd` y `lazygit` en el `PATH`. Los servidores de
  lenguaje y el depurador los instala Mason.

## Atajos propios más usados

| Atajo | Qué hace |
| --- | --- |
| `<Leader>m…` | CMake: `mg` generar, `mb` compilar, `mf` compilar solo el módulo del archivo actual, `mc` limpiar, `mr` ejecutar, `mR` ejecutar en otro terminal sin cerrar lo anterior, `md` depurar, `mD` depurar parando en excepciones, `ma` argumentos, `mx` parar, `mo` panel de compilación |
| `<Leader>ms…` | Elegir en CMake: `msp` preset, `msb` qué target compila, `msr` qué ejecutable se lanza |
| `<Leader>pr` | Guardar todo y reiniciar Neovim para recargar la configuración |
| `<Leader>T…` | Tests con neotest: `T<CR>` árbol de tests, `Tt` el test bajo el cursor, `Tf` el archivo, `Tc` asignar ejecutables desde CMake (una vez por build) |
| `<Leader>d…`, `F5` `F9` `F10` `F11` | Depurador; `<Leader>dh` valor bajo el cursor; `<Leader>dx` parar o no en excepciones de C++; `<Leader>da` engancharse a un proceso abierto, `<Leader>dD` soltarlo |
| `<Leader>dv` | Ver la variable: `HImage`, `HRegion`, `HObject` y `cv::Mat` como imagen; `HTuple` como texto (una lista larga, en ventana); `HDict` como árbol JSON, con `Enter` en sus imágenes y regiones |
| `<Leader>l…` | LSP; `lt` jerarquía de tipos, `lT` AST, `lk` info del símbolo |
| `<Leader>uh` / `<Leader>uv` | Mostrar u ocultar los type hints / los avisos del linter en línea (ocultos al arrancar) |
| `Alt+g` | Abrir u ocultar lazygit sin cerrarlo (un push en marcha no se corta) |
| `<Leader>gl` / `<Leader>gL` | Historial de git del archivo / de la línea |
| `<Leader>v`, luego `v` / `V` | Expandir / contraer la selección por sintaxis |
| `s` / `S` | Saltar a cualquier sitio con dos caracteres (leap) |
| `ys` `ds` `cs`, `S` en visual | Añadir, quitar y cambiar lo que rodea a un texto |
| `Ctrl+Shift+D` (WezTerm) | Pestaña con nvim y `claude` en el proyecto |
