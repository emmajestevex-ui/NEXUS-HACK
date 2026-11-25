# Nexus Interfaz

Prototipo visual SwiftUI independiente con selector azul/rojo, referencias gráficas originales y visor SceneKit con rotación automática. Los apartados son visuales y no modifican otras aplicaciones.

Los ocho recursos gráficos y 3D están incluidos. El script `python3 scripts/check_assets.py` comprueba sus SHA-256. Codemagic detiene la compilación si falta un recurso o su hash no coincide.

Workflow: `nexus-ios-unsigned` en `main`. Genera el proyecto con XcodeGen, compila para iPhone y empaqueta `NexusInterfaz-unsigned.ipa`. La IPA requiere una firma válida para instalarse. La compilación en macOS y la prueba en un iPhone aún no han sido ejecutadas.
