# Equipo de IA para NEXUS HACK

Este directorio organiza el trabajo entre varias IAs sin compartir secretos ni duplicar todo el código en cada conversación.

## Flujo recomendado

1. Codex crea una tarea usando `TASK_TEMPLATE.md`.
2. Se copian únicamente las capturas, el video y la descripción necesarios a Gemini.
3. Gemini devuelve una propuesta en el formato de `roles/gemini-design.md`.
4. La propuesta se guarda en `reviews/` o `animation-specs/`.
5. Claude revisa el diseño o el código usando `roles/claude-review.md`.
6. Codex integra los cambios, ejecuta las comprobaciones y prepara la compilación.

## Reglas

- Gemini y Claude entregan recomendaciones; solo Codex modifica la rama principal.
- Cada tarea debe tener criterios claros para saber cuándo está terminada.
- No se envían a ninguna IA claves `service_role`, certificados, archivos de firma ni contraseñas.
- No se colocan API keys de modelos dentro de la IPA.
- Las capturas y videos de referencia se usan para analizar la experiencia, no para copiar código propietario.

## Roles

- `roles/gemini-design.md`: diseño visual, animaciones y experiencia de usuario.
- `roles/claude-review.md`: revisión técnica, accesibilidad y riesgos.
- `roles/codex-integrator.md`: implementación, pruebas y compilación.

