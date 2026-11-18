# MyEffects for SignalRGB

Widget de escritorio para **controlar los efectos de SignalRGB desde Windows**: cambiar de tema, tema aleatorio, rotación automática y reordenar la lista. Gratis, ligero y **sin necesidad de SignalRGB Pro**.

> Hecho con Rainmeter + PowerShell. Sin nubes, sin suscripciones, sin configurar nada raro.

---

## Características

- **Widget compacto** (180×50 px) con el tema activo siempre a la vista
- **Lista desplegable** con todos los efectos instalados en SignalRGB
- **Rotación automática** con cuenta regresiva y barra de progreso tricolor (NO · 30 m · 60 m · 180 m · 360 m · 720 m)
- **Punto violeta** que marca el tema activo en la lista
- **Reordenar** la lista con ▲▼ (el orden personalizado se conserva al sincronizar)
- **Ocultar temas** de la lista con la ✕ de cada fila (no se borran de SignalRGB; el ⟳ los recupera a su posición)
- **Sincronización** con los efectos instalados (agrega nuevos, elimina desinstalados)
- **Atajos de teclado globales**:
  - `Ctrl + Alt + →` — siguiente tema
  - `Ctrl + Alt + ←` — tema anterior
  - `Ctrl + Alt + P` — pausar luces (Solid Color)
- **Version portable**: se descomprime, doble clic en `Iniciar.vbs` y listo

## Requisitos

- Windows 10/11
- [SignalRGB](https://signalrgb.com) instalado (versión gratuita — no se necesita Pro)
- No requiere permisos de administrador

## Instalación

1. Descarga `MyEffects-Portatil.zip` (en *Releases*)
2. Descomprime en un sitio fijo (por ejemplo, `Documentos`)
3. Doble clic en **`Iniciar.vbs`**

La primera vez registra el autoarranque y deja todo corriendo. En pantalla aparece **solo el widget MyEffects** — sin otros widgets. Con cada inicio de Windows arranca solo.

> Si mueves la carpeta después de instalarla, vuelve a ejecutar `Iniciar.vbs`.

## Uso

| Acción | Resultado |
|---|---|
| Clic en el widget | Abre la lista de efectos |
| Flechas ◁ ▷ | Tema anterior / siguiente |
| 🎲 Dado | Tema aleatorio |
| ⏰ Reloj | Ciclar rotación automática (NO → 30 m → … → 720 m) |
| ▲▼ en la lista | Reordenar |
| ✕ en la lista | Ocultar el tema de la lista (no se borra de SignalRGB) |
| ⟳ (cabecera) | Re-sincronizar con SignalRGB (recupera los temas ocultos a su posición) |
| Punto violeta | Indica el tema activo |
| Barra superior | Progreso hasta el próximo cambio automático |

La lista solo **lee** los efectos instalados en SignalRGB: para agregar o borrar efectos, usa SignalRGB y luego pulsa el ⟳.

## Cómo funciona

```
Widget (Rainmeter) ──► lanzadores VBS ──► motor (PowerShell)
     ▲                                        │
     └── registro de Windows ◄── aplica tema ──┘
                                              ▼
                                   SignalRgbLauncher.exe (SignalRGB)
```

- El widget publica su estado en el registro (`HKCU\Software\TemasRGB`) y lo lee con medidas de registro — no hay archivos de bloqueo ni dependencias externas
- Los temas se aplican con el lanzador oficial de SignalRGB (`SignalRgbLauncher.exe --url=effect/apply/...`), el mismo que usa su propia app
- Los residentes (motor, atajos, vigilante) usan tareas programadas del usuario y lanzadores invisibles: **cero ventanas de consola**
- Un *vigilante* relanza el motor y los atajos si murieran, y hay guardias anti-instancias-duplicadas

## Estructura

```
MyEffects-Portatil/
├─ Iniciar.vbs          primera puesta en marcha / arranque manual
├─ Detener.vbs          detiene todo y quita el autoarranque
├─ LEEME-Portatil.txt   instrucciones rápidas
├─ Rainmeter/           Rainmeter en modo portable (incluido, ya configurado)
└─ Herramienta/
   ├─ Temas-RGB.ps1     motor + comandos (siguiente, azar, rotar, reordenar...)
   ├─ Atajos-RGB.ps1    oyente de atajos globales
   ├─ Vigilante.ps1     revividor de residentes
   ├─ Sincronizar.ps1   sincroniza la lista con SignalRGB
   ├─ temas.txt         lista de efectos (un nombre por línea)
   └─ temas.log         registro de diagnóstico
```

## Desarrollo

El código fuente completo vive en [`Fuente/`](Fuente/):

- `Fuente/Herramienta/` — motor, atajos, vigilante, sincronización y lanzadores (PowerShell + VBS)
- `Fuente/Skin/MyEffects/` — el widget de Rainmeter (INI + iconos)

Todo son scripts planos: se pueden leer y modificar con cualquier editor. Para empaquetar una nueva versión portable se copia `Herramienta/` y `Skin/MyEffects/` junto a una carpeta de Rainmeter portable (`Rainmeter.exe /S /PORTABLE=1 /D=...`).

## Desinstalación

1. Doble clic en **`Detener.vbs`** (borra tareas, accesos y cierra todo)
2. Borra la carpeta

## Solución de problemas

- **No cambia el tema**: revisa que SignalRGB esté corriendo y mira `Herramienta\temas.log`
- **La lista está vacía**: pulsa el ⟳ de la cabecera (o verifica que tengas efectos instalados en SignalRGB)
- **La letra se ve borrosa**: vuelve a ejecutar `Iniciar.vbs` (aplica el fix de DPI automáticamente)
- Los cambios de tema tardan hasta ~6 s en aplicarse: SignalRGB tiene un período de gracia interno (es normal)

---

### Notas de terceros

- Este proyecto **no está afiliado a WhirlwindFX/SignalRGB** ni a Rainmeter
- El paquete portable incluye Rainmeter sin modificaciones (licencia [GPL v2](https://www.rainmeter.net/))
- Los nombres SignalRGB y Rainmeter pertenecen a sus respectivos autores

## Licencia

[MIT](LICENSE) © Alejandro Álvarez
