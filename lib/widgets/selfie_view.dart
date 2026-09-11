import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/selfie_camera.dart';

/// Espejo: la imagen de la cámara frontal, en el hueco de la brújula.
///
/// Es la otra vista del modo vertical, la que se alterna con la regla de
/// rumbos desde el botón de la barra de arriba. Abre la cámara al aparecer y
/// la suelta al desaparecer, así que fuera de esta vista la cámara queda libre
/// para otras aplicaciones.
class SelfieView extends StatefulWidget {
  const SelfieView({super.key, required this.camera});

  final SelfieCamera camera;

  @override
  State<SelfieView> createState() => _SelfieViewState();
}

class _SelfieViewState extends State<SelfieView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.camera.addListener(_onCameraChanged);
    // En segundo plano el sistema puede quitarnos la cámara de todas formas:
    // se suelta a propósito y se vuelve a abrir al volver, para no reaparecer
    // con la imagen congelada.
    _lifecycle = AppLifecycleListener(
      onPause: () => widget.camera.stop(),
      onResume: () => widget.camera.start(),
    );
    widget.camera.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.camera.removeListener(_onCameraChanged);
    widget.camera.stop();
    super.dispose();
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final preview = widget.camera.status == SelfieCameraStatus.ready
        ? widget.camera.buildPreview(context)
        : null;

    if (preview == null) return _CameraMessage(status: widget.camera.status);

    return Semantics(
      label: strings.selfieView,
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // El mismo cuadrado que el mando: los dos huecos miden igual y la
          // regla es la misma, así que el espejo queda alineado con el mando
          // por los dos lados.
          final side = math.min(constraints.maxWidth, constraints.maxHeight);

          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: side,
                height: side,
                // La imagen viene con la proporción de la cámara, más
                // estrecha que el cuadrado: se agranda hasta llenarlo de lado a
                // lado y lo que sobra por arriba y por abajo se recorta, en vez
                // de dejar dos franjas vacías a los lados.
                child: OverflowBox(
                  minWidth: side,
                  maxWidth: side,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: preview,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Lo que se ve mientras no hay imagen: abriéndose, sin permiso o sin cámara.
/// Sigue el mismo patrón que el aviso de calibración de la brújula.
class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.status});

  final SelfieCameraStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final opening =
        status == SelfieCameraStatus.opening ||
        status == SelfieCameraStatus.off;
    final denied = status == SelfieCameraStatus.denied;

    final title = opening
        ? strings.cameraOpening
        : denied
        ? strings.cameraDenied
        : strings.cameraUnavailable;
    final hint = opening
        ? null
        : denied
        ? strings.cameraDeniedHint
        : strings.cameraUnavailableHint;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              denied
                  ? Icons.no_photography_outlined
                  : Icons.photo_camera_front_outlined,
              size: 44,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
