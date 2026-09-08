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

- **Abajo, el mando.** No se desliza un pulsador: se desplaza **el fondo**, una
  superficie de plástico rugoso con un círculo translúcido que hace de marca.
  Dos líneas blancas cruzan el control de lado a lado, fijas al marco, y
  delimitan un cuadro de reposo en la esquina inferior derecha donde la marca
  descansa. Un icono en cada cuadrante recuerda qué hace cada eje: la linterna
  arriba a la derecha y el modo faro abajo a la izquierda.

  - Pasar la marca **por encima de la línea horizontal** enciende la linterna
    **al 100 %**. Si el dispositivo permite graduarla, seguir subiendo la
    atenúa, hasta el mínimo pegada al borde superior.
  - Pasarla **a la izquierda de la vertical** activa el **modo faro** (tema
    claro y pantalla que no se apaga) con el brillo al mínimo. Seguir hacia la
    izquierda lo sube, hasta el 100 % pegada al borde izquierdo.
  - Los dos ejes son independientes: en diagonal quedan las dos cosas activas.

  Al soltar, la marca sale desde donde esté el dedo y se queda ahí, salvo en
  tres sitios: dentro del cuadro de reposo vuelve al centro, y dentro de una
  banda de iluminación se centra en ella. También se puede tocar directamente
  el punto de destino.

  El sentido de la gradación está invertido entre los dos a propósito: de una
  linterna se quiere todo el brillo nada más encenderla, mientras que del faro
  se quiere ir subiendo.

  Cada encendido y cada apagado se confirma con una **vibración háptica**: un
  golpe más marcado al activar y otro más suave al desactivar, para notar el
  cambio sin mirar la pantalla. Si la linterna no llega a encenderse (no hay
  flash, o lo tiene otra aplicación) no vibra nada.

La aplicación usa **tema oscuro** siempre, salvo mientras el modo faro está
activo, que es cuando pasa a blanco para que la pantalla dé el máximo de luz.

## Avisos hápticos

Tres intensidades, en jerarquía, para poder distinguirlos sin mirar:

| Aviso | Cuándo |
| --- | --- |
| Fuerte (`heavyImpact`) | Un control se enciende |
| Medio (`mediumImpact`) | Un control se apaga |
| Tic (`selectionClick`) | La marca entra o sale de una banda de iluminación |

Cruzar una línea produce solo el aviso fuerte, no los dos: el salto entre el
reposo y una banda no cuenta como cambio de banda. Y mover la marca dentro de
un mismo tramo no vibra, o el mando zumbaría durante todo el arrastre.

## Regulación de la luz

Los dos ejes son analógicos, pero por razones distintas:

**El brillo de la pantalla** no tiene ninguna limitación: es un atributo de la
ventana, así que se ajusta con cualquier valor en todas las versiones de Android
e iOS. El nivel del mando se traduce a brillo con un **suelo del 30 %**, a
propósito: con la pantalla apagada del todo no se vería el mando para volver a
subirla. El modo claro y la inhibición del apagado van siempre juntos.

**La intensidad del flash** depende del dispositivo:

| Plataforma | Gradación |
| --- | --- |
| iOS | Siempre, con flash. `setTorchModeOn(level:)` acepta un valor continuo entre 0 y 1 desde iOS 6 |
| Android 13+ con soporte | `turnOnTorchWithStrengthLevel()`, en tantos escalones como declare `FLASH_INFO_STRENGTH_MAXIMUM_LEVEL` |
| Resto de Android | No: solo encendido y apagado |

Hay móviles con Android 13 o superior que declaran un único nivel, así que **no
basta con mirar la versión del sistema**. La aplicación consulta la capacidad al
arrancar y, cuando no la hay, el eje vertical del mando vuelve a comportarse
como un interruptor: salta arriba del todo en lugar de quedarse a media altura.

## El canal nativo de la linterna

No hay ningún plugin de terceros para el flash: `torch_light`, que se usaba
antes, solo llama a `setTorchMode(id, true/false)` y no puede graduar. En su
lugar hay un canal de plataforma propio, `com.jgermade.compasstorch/torch`, con
dos métodos:

- `capabilities` → `{available, gradual}`
- `setTorch(enabled, intensity)` — la intensidad va de 0 a 1 y cada lado la
  traduce a su escala; se ignora donde no se puede regular

Está implementado en
[`TorchController.kt`](android/app/src/main/kotlin/com/jgermade/compasstorch/TorchController.kt)
y en [`AppDelegate.swift`](ios/Runner/AppDelegate.swift). El código de iOS vive
dentro de `AppDelegate.swift` en vez de en un fichero aparte porque añadir un
fichero nuevo al proyecto de Xcode obliga a editar `project.pbxproj` a mano; el
de Android sí está separado, porque Gradle compila todo el directorio de fuentes.

En Dart, `DeviceServices` es la costura que permite probar toda la lógica sin
tocar los canales de plataforma. Los cambios de nivel durante el arrastre no se
encolan: se guarda solo el último valor y se manda cuando termina el envío
anterior, así el flash converge sin saturar el canal.

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
| `screen_brightness` | Brillo de la pantalla, solo dentro de la aplicación |
| `wakelock_plus` | Impedir que la pantalla se apague |

La linterna va por canal propio, sin dependencia externa.

En Android se usa `CameraManager`, que **no** requiere el permiso `CAMERA` para
la linterna. `screen_brightness` cambia el brillo únicamente de esta aplicación,
así que tampoco necesita `WRITE_SETTINGS`. En iOS los sensores de movimiento no
piden permiso, pero se declara `NSMotionUsageDescription`.

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
gravedad), la geometría del mando en `PadGeometry` (bandas, gradación invertida,
ida y vuelta entre posición y nivel, y dónde se queda la marca al soltarla), los
gestos sobre el mando, y la lógica de los controles —jerarquía de vibraciones,
gradación, suelo de brillo y coalescencia de envíos— con un doble de
`DeviceServices`, sin tocar los canales de plataforma.

`PadGeometry` está aparte del widget justamente para eso: toda la geometría es
una función pura, comprobable sin simular gestos.

El código nativo (Kotlin y Swift) no tiene pruebas propias: lo verifica la
compilación en CI. **Nada de esto se ha ejecutado todavía en un teléfono real**,
así que el comportamiento del flash y del brillo sobre hardware está sin
confirmar.
