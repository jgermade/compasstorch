# compasstorch

Brújula con un mando deslizable para la linterna y el "modo faro". Flutter,
Android e iOS.

## Qué hace

La pantalla se divide en dos mitades:

- **Arriba, la brújula.** Cambia de forma según cómo se sujete el teléfono:
  - **En horizontal** (tumbado, como se lee una brújula de verdad): rosa de los
    vientos que gira, con la aguja marcando el norte magnético.
  - **En vertical** (levantado, apuntando a algo): una regla de líneas
    verticales que se desplaza con el rumbo al que apunta la parte trasera del
    teléfono, con los grados marcados y la elevación sobre el horizonte.

  El cambio lo decide la inclinación del plano del teléfono (`tilt`), con una
  banda muerta entre 35° y 55° para que la vista no oscile en el límite.

- **Abajo, el mando.** Un pulsador que descansa en la esquina inferior derecha
  y se arrastra en dos ejes independientes:
  - **Hacia arriba** → enciende la linterna (flash).
  - **Hacia la izquierda** → activa el **modo faro**: tema claro, brillo al
    máximo y la pantalla no se apaga sola.
  - **En diagonal**, hacia la esquina superior izquierda, quedan las dos
    activas. Devolver el pulsador a su esquina las apaga.

  También se puede tocar directamente la esquina a la que se quiere llevar el
  pulsador.

  Cada encendido y cada apagado se confirma con una **vibración háptica**: un
  golpe más marcado al activar y otro más suave al desactivar, para notar el
  cambio sin mirar la pantalla. Si la linterna no llega a encenderse (no hay
  flash, o lo tiene otra aplicación) no vibra nada.

La aplicación usa **tema oscuro** siempre, salvo mientras el modo faro está
activo, que es cuando pasa a blanco para que la pantalla dé el máximo de luz.

## Cómo se calcula el rumbo

No se usa ningún plugin de brújula: la orientación se deriva del acelerómetro y
el magnetómetro (`sensors_plus`) reproduciendo el cálculo de
`SensorManager.getRotationMatrix` de Android. Con el vector de gravedad y el del
campo magnético se construye la matriz de rotación del dispositivo respecto al
mundo (X = este, Y = norte magnético, Z = arriba) y de ahí salen los tres datos
que necesita la interfaz: el rumbo del borde superior, el rumbo de la cámara
trasera y la inclinación.

Ambas lecturas pasan por un filtro paso bajo para que la aguja no tiemble.

**El norte es el magnético**: no se aplica corrección de declinación, así que
puede diferir unos grados del norte geográfico según la zona. Como cualquier
brújula de móvil, necesita calibrarse moviendo el teléfono en forma de ocho, y
se desvía cerca de metales o imanes.

## Dependencias

| Paquete | Para qué |
| --- | --- |
| `sensors_plus` | Acelerómetro y magnetómetro (rumbo e inclinación) |
| `torch_light` | Encender y apagar el flash |
| `screen_brightness` | Brillo al máximo, solo dentro de la aplicación |
| `wakelock_plus` | Impedir que la pantalla se apague |

`torch_light` usa `CameraManager.setTorchMode` en Android, que **no** requiere el
permiso `CAMERA`. `screen_brightness` cambia el brillo únicamente de esta
aplicación, así que tampoco necesita `WRITE_SETTINGS`. En iOS los sensores de
movimiento no piden permiso, pero se declara `NSMotionUsageDescription`.

## Compilación y publicación

Dos workflows en `.github/workflows`:

### `build.yml` — comprobar y compilar

Se dispara en cada push a `main` y en cada pull request, y además se puede
reutilizar desde otro workflow (`workflow_call`) indicando qué referencia
compilar. Tres trabajos:

1. `test`: `dart format --set-exit-if-changed`, `flutter analyze` y
   `flutter test`.
2. `android`: `flutter build apk --release`, publicado como artefacto `apk`.
3. `ios`: `flutter build ios --release --no-codesign` y empaquetado del
   `Runner.app` como `.ipa`, publicado como artefacto `ipa`.

Los dos trabajos de compilación esperan a que `test` pase. El de iOS corre en
un runner de macOS, que consume minutos a un ritmo mucho mayor que el de Linux:
si el gasto en pull requests molesta, lo suyo es limitarlo a `push` y
`workflow_call`.

### `release.yml` — versionar y publicar

Se lanza a mano (`workflow_dispatch`) eligiendo si sube `patch`, `minor` o
`major`. Hace, en este orden:

1. `bump`: calcula la nueva versión a partir de la de `pubspec.yaml`, sube
   también el código de compilación (`1.2.3+7` → `1.2.4+8`), escribe el
   `pubspec.yaml`, hace commit, crea la etiqueta `vX.Y.Z` y la sube. Aborta si
   la etiqueta ya existe.
2. `build`: reutiliza `build.yml` **sobre el commit que acaba de crear**, no
   sobre el que disparó el workflow.
3. `publish`: descarga los artefactos, los renombra con la versión y crea la
   release de GitHub con el APK y el IPA adjuntos. Las notas salen de los
   commits desde la etiqueta anterior.

Necesita que la rama admita el push del bot: con `main` protegida hay que
darle permiso a `github-actions[bot]` o lanzar la release desde otra rama.

### Firma

Ninguno de los dos binarios está firmado para distribución:

- El **APK** se firma con la clave de depuración, que es lo que trae la
  plantilla de Flutter (`android/app/build.gradle.kts`). Se instala a mano,
  pero no vale para Google Play. Para publicar hay que crear un keystore,
  guardarlo en los secretos del repositorio y añadir su `signingConfig`.
- El **IPA** sale sin firmar, porque en CI no hay certificado de Apple. Sirve
  para inspeccionarlo o volver a firmarlo, no para instalarlo tal cual.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Los tests cubren el cálculo de la orientación con vectores conocidos (teléfono
tumbado y levantado apuntando a cada rumbo, caída libre, campo alineado con la
gravedad), los gestos del mando y la lógica de los dos controles —vibración
incluida— con un doble de `DeviceServices`, sin tocar los canales de
plataforma.
