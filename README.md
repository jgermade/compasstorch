# compasstorch

Brújula con un mando deslizable para la linterna y el "modo faro". Flutter,
Android e iOS.

## Qué hace

La pantalla se divide en dos mitades:

- **Arriba, la brújula.** Cambia de forma según cómo se sujete el teléfono:
  - **En horizontal** (tumbado, como se lee una brújula de verdad): rosa de los
    vientos que gira, con la aguja marcando el norte magnético. En el centro,
    detrás de los grados y del rumbo, una **burbuja de nivel** se va hacia el
    lado que se levanta; cuando el teléfono está plano se enciende el borde del
    círculo central y una **vibración suave** lo confirma, para no tener que
    mirar la pantalla mientras se nivela.
  - **En vertical** (levantado, apuntando a algo): una regla de líneas
    verticales que se desplaza con el rumbo al que apunta la parte trasera del
    teléfono, con los grados marcados, y a su derecha una barra vertical con la
    **elevación sobre el horizonte**. En vertical hay además una segunda vista,
    el **espejo**: la imagen de la cámara frontal ocupando el mismo hueco.

  El cambio lo decide la inclinación del plano del teléfono (`tilt`), con una
  banda muerta entre 35° y 55° para que la vista no oscile en el límite.

  Encima de la brújula, en las esquinas, el estado de los dos controles: el
  modo faro arriba a la izquierda y la linterna arriba a la derecha, cada uno
  con su porcentaje hacia el centro y con el mismo icono que lleva su eje en el
  mando. Los dos son pulsables y los dos conmutan igual: **apagado o al
  100 %**, sin recuperar el nivel de antes. El chip es el atajo para tener toda
  la luz de golpe; graduar es cosa del mando, que se coloca solo donde
  corresponda.

  En medio de esos dos chips va la vista activa. Con el teléfono tumbado es
  solo el icono de la brújula, porque no hay nada que elegir. Levantado se
  convierte en un **botón con dos iconos**, la regla y la cámara: el de la
  vista que se está viendo va encendido y el otro tenue, y tocarlo cambia entre
  las dos. Al bajar el teléfono se vuelve siempre a la regla.

- **Abajo, el mando.** No se desliza un pulsador: se desplaza **el fondo**, una
  superficie de plástico rugoso con un círculo translúcido que hace de marca.
  Dos líneas translúcidas cruzan el control de lado a lado, fijas al marco, y
  delimitan un cuadro de reposo en la esquina inferior derecha donde la marca
  descansa. Un icono en cada cuadrante recuerda qué hace cada eje: la linterna
  arriba a la derecha y el modo faro abajo a la izquierda.

  - Pasar la marca **por encima de la línea horizontal** enciende la linterna
    **al mínimo**. Si el dispositivo permite graduarla, seguir subiendo la
    sube, hasta el 100 % pegada al borde superior.
  - Pasarla **a la izquierda de la vertical** activa el **modo faro** (tema
    claro y pantalla que no se apaga) con el brillo al mínimo. Seguir hacia la
    izquierda lo sube, hasta el 100 % pegada al borde izquierdo.
  - Los dos ejes son independientes: en diagonal quedan las dos cosas activas.

  Al soltar, la marca sale desde donde esté el dedo y se queda ahí, salvo en
  tres sitios: dentro del cuadro de reposo vuelve al centro, y dentro de una
  banda de iluminación se centra en ella. También se puede tocar directamente
  el punto de destino.

  Los dos ejes gradúan en el mismo sentido: cruzar la línea enciende al
  mínimo, y alejarse de ella sube la luz. Así el mando se lee igual mires el
  eje que mires.

  Cada encendido y cada apagado se confirma con una **vibración háptica**: un
  golpe más marcado al activar y otro más suave al desactivar, para notar el
  cambio sin mirar la pantalla. Si la linterna no llega a encenderse (no hay
  flash, o lo tiene otra aplicación) no vibra nada.

  Mantener el dedo **cinco segundos en el cuadro de reposo** activa o desactiva
  que la pantalla se quede encendida (ver más abajo). Se hace ahí porque es el
  único sitio del mando donde el dedo quieto no cambia ninguna luz, y la
  vibración confirma el cambio.

La aplicación usa **tema oscuro** siempre, salvo mientras el modo faro está
activo, que es cuando pasa a blanco para que la pantalla dé el máximo de luz.

**La pantalla no se apaga sola** mientras la aplicación está abierta: se usa a
oscuras, apuntando a otro sitio y sin tocarla en un rato. La inhibición se
puede quitar manteniendo pulsado el cuadro de reposo del mando; mientras esté
quitada, los dos iconos del mando se pintan **en escala de grises**. El modo
faro mantiene la pantalla encendida de todas formas, la haya quitado o no.

## El espejo

Con el teléfono levantado, el botón del medio de la barra cambia la regla de
rumbos por la imagen de la cámara frontal. Es lo que le faltaba a una linterna
para alumbrarse a uno mismo: luz y espejo a la vez, sin salir de la aplicación.

La cámara se abre al entrar en la vista y **se suelta al salir**, al bajar el
teléfono y al irse la aplicación a segundo plano, así que fuera del espejo
queda libre para otras aplicaciones y no gasta batería. La imagen llega ya
invertida como un espejo: tanto CameraX en Android como AVFoundation en iOS
reflejan la vista previa de la cámara frontal, así que la aplicación no le da
la vuelta por su cuenta.

El **permiso de cámara** se pide la primera vez que se toca el botón. Si no se
da, o si el dispositivo no tiene cámara frontal utilizable, la vista lo explica
en su sitio y el resto de la aplicación sigue igual: el espejo es lo único que
depende de la cámara.

En Dart, `SelfieCamera` es la costura equivalente a `DeviceServices`: una
interfaz con la implementación real encima del plugin `camera`, para poder
probar la vista sin canales de plataforma.

## Idiomas

La aplicación está en **castellano e inglés**, y el inglés hace de reserva
cuando el sistema pide cualquier otro idioma. Se traducen los textos de la
interfaz, las abreviaturas de los rumbos (`SO`/`SW`, `O`/`W`…) y lo que leen
los lectores de pantalla.

Las traducciones se escriben a mano en `lib/l10n`: una clase abstracta
`AppStrings` con una implementación por idioma y su `LocalizationsDelegate`.
Son pocos textos, así que no compensa generar código desde ficheros ARB. El
inglés encabeza `supportedLocales` y por eso es el idioma al que cae
`basicLocaleListResolution` cuando no hay coincidencia. Los mensajes de error
de los controles no viajan como texto: `ControlsController` devuelve un
`ControlsError` y la pantalla lo traduce al mostrarlo.

## Avisos hápticos

Tres intensidades, en jerarquía, para poder distinguirlos sin mirar:

| Aviso | Cuándo |
| --- | --- |
| Fuerte (`heavyImpact`) | Un control se enciende |
| Medio (`mediumImpact`) | Un control se apaga |
| Suave (`lightImpact`) | La burbuja de nivel se centra |
| Tic (`selectionClick`) | La marca entra o sale de una banda de iluminación |

Cruzar una línea produce solo el aviso fuerte, no los dos: el salto entre el
reposo y una banda no cuenta como cambio de banda. Y mover la marca dentro de
un mismo tramo no vibra, o el mando zumbaría durante todo el arrastre.

Tres avisos son del mando y el cuarto de la brújula, así que no se solapan. El
del nivel se emite solo al **entrar** en la zona nivelada, y con holgura: se
entra por debajo de 0,02 de inclinación y no se sale hasta pasar de 0,035, o el
pulso de la mano lo dispararía sin parar. Con el teléfono ya plano al arrancar
no vibra: no hay ningún cambio que confirmar.

## Regulación de la luz

Los dos ejes son analógicos, pero por razones distintas:

**El brillo de la pantalla** no tiene ninguna limitación: es un atributo de la
ventana, así que se ajusta con cualquier valor en todas las versiones de Android
e iOS. El nivel del mando se traduce a brillo con un **suelo del 30 %**, a
propósito: con la pantalla apagada del todo no se vería el mando para volver a
subirla. El modo claro va siempre con el faro; la inhibición del apagado ya
viene puesta desde el arranque, así que el faro solo se asegura de que siga
puesta mientras dure.

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
mundo (X = este, Y = norte magnético, Z = arriba) y de ahí salen los datos que
necesita la interfaz: el rumbo del borde superior, el rumbo de la cámara
trasera, la inclinación, la elevación y, para la burbuja de nivel, cuánto se
inclina el teléfono sobre cada eje de la pantalla.

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
| `camera` | Vista previa de la cámara frontal (el espejo) |

La linterna va por canal propio, sin dependencia externa.

En Android la linterna usa `CameraManager.setTorchMode`, que **no** requiere el
permiso `CAMERA`; el que sí lo requiere es el espejo, así que el permiso está
declarado en el manifiesto y lo pide el propio plugin al abrir la cámara. La
cámara y la cámara frontal se declaran como características **opcionales**,
para no dejar fuera del listado a los dispositivos que no las tengan.
`screen_brightness` cambia el brillo únicamente de esta aplicación, así que
tampoco necesita `WRITE_SETTINGS`. En iOS los sensores de movimiento no piden
permiso, pero se declara `NSMotionUsageDescription`, y el espejo añade
`NSCameraUsageDescription`.

Queda **sin comprobar en hardware** si la linterna y el espejo conviven: el
flash va por la cámara trasera y el espejo por la frontal, pero hay
dispositivos que no dejan las dos cosas a la vez.

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
gravedad), la geometría del mando en `PadGeometry` (bandas, sentido de la
gradación, ida y vuelta entre posición y nivel, y dónde se queda la marca al
soltarla), los gestos sobre el mando, la lógica de los controles —jerarquía de
vibraciones, gradación, suelo de brillo y coalescencia de envíos— con un doble
de `DeviceServices`, sin tocar los canales de plataforma, el aviso háptico del
nivel (que no se repite ni se dispara solo al arrancar), el botón que alterna
la regla y el espejo —con un doble de `SelfieCamera`, que comprueba también que
la cámara se suelta al salir de la vista— y las traducciones, incluida la
vuelta al inglés con un idioma sin traducir.

`PadGeometry` está aparte del widget justamente para eso: toda la geometría es
una función pura, comprobable sin simular gestos.

El código nativo (Kotlin y Swift) no tiene pruebas propias: lo verifica la
compilación en CI.

## Icono

El original es `CompassTorch.svg`: una brújula cuya aguja es una linterna. De
ahí salen todos los tamaños de Android e iOS —incluidos el icono adaptativo y
su capa monocroma para los iconos temáticos de Android 13— con:

```bash
pip install pillow cairosvg
python3 tool/generate_app_icons.py
```

El dibujo se encuadra en un cuadrado centrado en el centro del lienzo del SVG,
que es donde está el círculo de la brújula. Ajustarlo a la caja del contenido
lo dejaría descentrado, porque la llama de la linterna sobresale por arriba.
 **Nada de esto se ha ejecutado todavía en un teléfono real**,
así que el comportamiento del flash y del brillo sobre hardware está sin
confirmar.
