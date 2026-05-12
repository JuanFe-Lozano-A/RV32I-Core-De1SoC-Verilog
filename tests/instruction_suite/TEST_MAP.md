# 🗺️ Mapa de Pruebas Individuales RV32I

Esta carpeta contiene un programa de prueba independiente para cada instrucción del set base RV32I. Cada prueba incluye su archivo `.hex` (binario) y su `.csv` (traza esperada).

## 1. Aritmética e Inmediatos (I-Type)
- `addi.hex` / `addi.csv`
- `slti.hex` / `slti.csv`
- `sltiu.hex` / `sltiu.csv`
- `andi.hex` / `andi.csv`
- `ori.hex` / `ori.csv`
- `xori.hex` / `xori.csv`
- `slli.hex` / `slli.csv`
- `srli.hex` / `srli.csv`
- `srai.hex` / `srai.csv`

## 2. Operaciones entre Registros (R-Type)
- `add.hex` / `add.csv`
- `sub.hex` / `sub.csv`
- `sll.hex` / `sll.csv`
- `slt.hex` / `slt.csv`
- `sltu.hex` / `sltu.csv`
- `xor.hex` / `xor.csv`
- `srl.hex` / `srl.csv`
- `sra.hex` / `sra.csv`
- `or.hex` / `or.csv`
- `and.hex` / `and.csv`

## 3. Carga y Almacenamiento (Load/Store)
- `sb.hex` / `sb.csv`
- `sh.hex` / `sh.csv`
- `sw.hex` / `sw.csv`
- `lb.hex` / `lb.csv`
- `lh.hex` / `lh.csv`
- `lw.hex` / `lw.csv`
- `lbu.hex` / `lbu.csv`
- `lhu.hex` / `lhu.csv`

## 4. Saltos Condicionales (Branches)
- `beq.hex` / `beq.csv`
- `bne.hex` / `bne.csv`
- `blt.hex` / `blt.csv`
- `bge.hex` / `bge.csv`
- `bltu.hex` / `bltu.csv`
- `bgeu.hex` / `bgeu.csv`

## 5. Saltos Incondicionales e Inmediatos Superiores
- `lui.hex` / `lui.csv`
- `auipc.hex` / `auipc.csv`
- `jal.hex` / `jal.csv`
- `jalr.hex` / `jalr.csv`

## 6. Instrucciones de Sistema
- `ecall.hex` / `ecall.csv`
- `ebreak.hex` / `ebreak.csv`

---
**Nota:** Para cargar una prueba, simplemente usa el `vga_viewer.py` y navega hasta la carpeta `instruction_suite`. Al seleccionar el archivo `.hex`, se desplegará automáticamente al procesador.
