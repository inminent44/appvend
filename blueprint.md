# Blueprint: VaraNova POS

## Visión General

VaraNova POS es una aplicación de punto de venta (POS) diseñada para pequeños y medianos negocios. Permite gestionar ventas, inventario y finanzas de una manera simple y eficiente. La aplicación se divide en dos modos principales: "Cajero", para las operaciones del día a día, y "Admin", para la gestión del negocio.

## Estilo y Diseño

La aplicación sigue un diseño moderno, limpio y coherente, definido en `lib/app_theme.dart`. Los principios de diseño son:

- **Claridad:** La información se presenta de forma clara y concisa.
- **Consistencia:** Se utiliza un tema de colores y tipografía unificado en toda la aplicación.
- **Eficiencia:** Las acciones más comunes son fácilmente accesibles.

### Paleta de Colores

- **Primario:** `AppTheme.primary` (un tono de verde azulado oscuro)
- **Acento:** `AppTheme.accent` (un color complementario para resaltar elementos)
- **Fondo:** `AppTheme.background`
- **Tarjetas:** `AppTheme.cardColor`
- **Texto Primario:** `AppTheme.textPrimary`
- **Texto Secundario:** `AppTheme.textSecondary`

### Tipografía

Se utiliza el paquete `google_fonts` con la fuente "Roboto" para una apariencia moderna y legible.

## Características Implementadas

### Modo Cajero

- **Pantalla de Cuentas (`caja_screen.dart`):**
    - Muestra una cuadrícula de cuentas abiertas y cerradas.
    - Permite crear nuevas cuentas y acceder a las existentes.
    - Diseño basado en tarjetas para una fácil visualización.

- **Detalle de Cuenta (`cuenta_detalle_screen.dart`):**
    - Lista los productos agregados a una cuenta.
    - Permite agregar nuevos productos desde un catálogo.
    - Muestra el total de la cuenta y la opción de cobrar.
    - Interfaz de cobro clara y fácil de usar.

### Modo Admin

- **Login (`login_screen.dart`):**
    - Pantalla de inicio de sesión segura y atractiva.
    - Soporte para registro de administrador y recuperación de contraseña.

- **Panel Principal (`main_admin_screen.dart`):**
    - Dashboard con acceso a las principales funciones de administración.
    - Diseño de tarjetas para una navegación intuitiva (Inventario, Cierres, Backup, etc.).

- **Gestión de Inventario (`inventario_screen.dart`):**
    - Lista de productos con información de stock y precio.
    - Indicadores visuales de colores para el nivel de stock (verde, naranja, rojo).
    - Búsqueda de productos por nombre o ID.
    - Botón flotante para agregar nuevos productos.

- **Agregar/Editar Producto (`agregar_producto_screen.dart`):**
    - Formulario claro y organizado para añadir o modificar productos.
    - Campos agrupados por secciones (Información Básica, Precios y Stock).
    - Validación de campos y manejo de errores.

- **Cierres de Caja (`cierres_admin_screen.dart`):**
    - Lista de los cierres de caja importados.
    - Tarjeta de resumen con el total de ventas del día.
    - Botón para importar archivos de cierre.
    - Hoja de detalles para ver el resumen de cada cierre.

- **Backup y Sistema (`backup_screen.dart`):**
    - Interfaz clara para exportar e importar la base de datos.
    - Diálogos de confirmación para acciones destructivas.
    - Opción para cambiar la contraseña de administrador.
    - Diseño basado en tarjetas para separar las acciones por categoría.
