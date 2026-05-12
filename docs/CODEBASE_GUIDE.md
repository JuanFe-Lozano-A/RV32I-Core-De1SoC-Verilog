# 📖 Guía Detallada del Código: RV32I-FPGA SoC

Esta guía está diseñada para ayudarte a navegar y entender la implementación profunda de este procesador RISC-V en una FPGA DE1-SoC.

## 1. Estructura de Carpetas

*   `rtl/`: Lógica de hardware en Verilog.
    *   `rtl/core/`: El núcleo del procesador (Unidad de Control, PC, registros).
    *   `rtl/datapath/`: Unidades de cálculo (ALU, Generador de Inmediatos).
    *   `rtl/memory/`: Implementaciones de memoria (Harvard vs Von Neumann).
    *   `rtl/vga/`: Sistema de monitoreo visual.
*   `tests/`: Programas de prueba en ensamblador y archivos `.hex`.
*   `docs/`: Diagramas y documentación técnica.

---

## 2. Jerarquía de Módulos (Top-Down)

### Nivel 1: El SoC (`SingleCore_FPGA_RV32I_VGA.v`)
Es el contenedor principal. Define cómo el chip se conecta con el mundo exterior:
*   **Reloj:** Divide los 50MHz de la placa a 25MHz para el estándar VGA.
*   **Interconexión:** Une el núcleo (`u_core`) con la memoria (`u_mem`) y el monitor (`u_text_engine`).
*   **Botones:** Gestiona el avance por pasos (`step_forward`) y el retroceso en el tiempo (`step_backward`).

### Nivel 2: El Núcleo (`rv32i_core.v`)
Orquesta el ciclo de ejecución de cada instrucción. Al ser un diseño de **ciclo único**, todas las etapas ocurren entre un pulso de reloj y otro:
1.  **Fetch:** Obtiene la instrucción desde la memoria usando el PC.
2.  **Decode:** Envía el opcode a la `control_unit.v`.
3.  **Execute:** Usa la ALU para cálculos o cálculo de direcciones.
4.  **Memory:** Lee/Escribe datos si la instrucción es de carga/almacenamiento.
5.  **Write-back:** Guarda el resultado final en el archivo de registros.

### Nivel 3: Los Componentes Atómicos
*   **`control_unit.v`:** El diccionario que traduce instrucciones a señales eléctricas.
*   **`alu.v`:** Realiza sumas, restas, operaciones lógicas y comparaciones.
*   **`register_file.v`:** Contiene los 32 registros de propósito general (x0 a x31).

---

## 3. Flujo de Ejecución y Monitoreo

### El Monitor VGA (Modo Pip-Boy)
Una característica única de este proyecto es que el hardware monitoriza su propio estado. El módulo `text_engine.v` actúa como un "osciloscopio" de texto que lee las señales internas del procesador y las dibuja en pantalla:
*   No usa un software para mostrar los datos; es lógica cableada que lee directamente los registros.
*   Permite ver el resultado de la ALU y los operandos RS1/RS2 en tiempo real.

### Ciclo de Paso a Paso
1.  Presionas `KEY[1]`.
2.  La señal `step_forward` viaja al módulo `pc.v`.
3.  El PC se actualiza y la lógica combinacional procesa la nueva instrucción instantáneamente.
4.  El sistema de historial (`history_buffer.v`) guarda una copia del estado previo por si decides usar `KEY[2]` para retroceder.

---

## 4. Diferencias de Arquitectura (Configurables)

El proyecto puede compilarse en dos modos mediante macros de Verilog:

1.  **Harvard:** Memorias físicas separadas para código y datos. Es más simple pero no permite programas que se modifican a sí mismos o leer constantes embebidas en el código.
2.  **Von Neumann:** Usa `unified_memory.v`. Ambas memorias son la misma, permitiendo trucos avanzados como leer datos desde el segmento de código (ej. el test `const_read.hex`).

---

## 5. Cómo Aprender el Código In-Depth

1.  **Sigue un ADD:** Mira cómo viajan las señales desde que el Opcode llega a la unidad de control hasta que el resultado de la ALU vuelve al Registro de Destino (RD).
2.  **Sigue un LOAD:** Mira cómo la dirección calculada por la ALU viaja a la memoria, y cómo el dato que sale de la memoria vuelve al procesador.
3.  **Analiza el Rollback:** Mira en `rv32i_core.v` cómo el historial captura el estado de los registros antes de que cambien.
