# Cacahuete Comando 🥜

Mascota de escritorio para Windows: un cacahuete con bandana roja y un AK de juguete que patrulla tu escritorio, dispara, trepa por las ventanas, se vuelve loco y te recuerda beber agua. Le acompaña **Pipo**, un recluta pipa que hace de secretario (temporizador, pomodoro, recordatorios, notas e historial del portapapeles).

No necesita instalar nada: está escrito en C# dentro de un script de PowerShell y se compila a un `.exe` en tu propio PC.

## Instalación

1. Descarga el repositorio (botón **Code → Download ZIP**) y descomprímelo en una carpeta que no vayas a borrar, por ejemplo `Documentos\Cacahuete`.
2. Haz doble clic en **`Montar cacahuete.bat`**. Crea `Cacahuete.exe` y lo arranca.
3. A partir de ahí, ábrelo con **`Cacahuete.exe`**. La primera vez se añade solo al inicio de Windows (se puede quitar desde el menú).

> Si tu antivirus lo bloquea (Kaspersky lo hace), añade la carpeta del cacahuete a sus exclusiones. El `.exe` lanza PowerShell en segundo plano para actualizarse cuando cambia `cacahuete.ps1`.

## Cómo se usa

**Cacahuete**
- **Clic izquierdo:** dispara hacia el ratón. Si le pinchas mucho, entra en **modo loco**.
- **Arrastrar:** lo coges y lo lanzas. Desde muy alto abre paracaídas.
- **Clic derecho:** menú con armas (bazooka de mantequilla, granada de pipa, lanzaconfeti), trepar a ventanas o al techo, trinchera, viajar a otra pantalla, baile, siesta, minijuego de esquivar balas, diario de guerra, tamaño, no molestar y ajustes.

**Pipo** (clic en él)
- Temporizador y pomodoro (25/5). Mientras trabajas, el cacahuete no dispara.
- Recordatorios (se guardan en `recordatorios.txt`).
- Notas rápidas (`notas.txt`).
- Los 10 últimos textos copiados (solo en memoria).
- Hora y batería.

**Además**
- Funciona con varias pantallas y con gestores en mosaico como Hyprland4Win.
- Se esconde cuando pones algo a pantalla completa.
- Reacciona a tus apps (Steam, Spotify, YouTube…) y entra en modo concentración cuando programas.
- Recordatorios de levantarte y beber agua, saludo según la hora y resumen diario.

## Archivos

| Archivo | Para qué sirve |
| --- | --- |
| `cacahuete.ps1` | Todo el código (C# embebido en PowerShell) |
| `Montar cacahuete.bat` | Compila `Cacahuete.exe` y lo arranca |
| `Cacahuete.bat` | Arranca el cacahuete (lo monta si hace falta) |
| `sprites/` | Gráficos realistas opcionales (Ajustes → General) |

## Requisitos

Windows 10 u 11 con PowerShell 5.1 (viene de serie).
