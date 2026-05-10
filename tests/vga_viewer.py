import tkinter as tk
from tkinter import ttk, messagebox
import csv
import sys
import os
import shutil
import subprocess

class RV32IManager(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("RV32I System Manager & VGA Viewer")
        self.geometry("1000x800")
        self.configure(bg="#001100")
        
        # Current view container
        self.container = tk.Frame(self, bg="#001100")
        self.container.pack(side="top", fill="both", expand=True)
        
        self.frames = {}
        self.show_menu()

    def show_menu(self):
        # Clear ALL existing frames to prevent stacking
        for frame in self.frames.values():
            frame.destroy()
        self.frames.clear()
        
        frame = SelectionMenu(parent=self.container, controller=self)
        self.frames["menu"] = frame
        frame.pack(fill="both", expand=True)

    def open_viewer(self, csv_path):
        try:
            with open(csv_path, "r", encoding="utf-8") as f:
                reader = csv.reader(f)
                data = list(reader)
            
            if len(data) < 2:
                messagebox.showerror("Error", "CSV file is empty or invalid.")
                return

            # Clear ALL existing frames before opening viewer
            for frame in self.frames.values():
                frame.destroy()
            self.frames.clear()

            viewer = VGAPipBoyViewer(parent=self.container, controller=self, csv_data=data[1:])
            self.frames["viewer"] = viewer
            viewer.pack(fill="both", expand=True)
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load CSV:\n{str(e)}")

class SelectionMenu(tk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent, bg="#001100")
        self.controller = controller
        
        # Get absolute paths relative to this script
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.root_dir = os.path.dirname(self.script_dir)
        
        # Style setup
        style = ttk.Style()
        style.theme_use("clam")
        style.configure("Treeview", 
                        background="#001100", 
                        foreground="#39ff14", 
                        fieldbackground="#001100", 
                        font=("Consolas", 10),
                        borderwidth=1,
                        relief="flat")
        style.configure("Treeview.Heading", 
                        background="#002200", 
                        foreground="#39ff14", 
                        font=("Consolas", 11, "bold"),
                        relief="flat")
        style.map("Treeview.Heading",
                  background=[('active', '#004400')],
                  foreground=[('active', '#39ff14')])
        
        style.map("Treeview", 
                  background=[('selected', '#004400')],
                  foreground=[('selected', '#39ff14')])
        
        # Remove the dotted focus line
        style.layout("Treeview", [('Treeview.treearea', {'sticky': 'nswe'})])
        
        # Scrollbar Styling
        style.configure("Vertical.TScrollbar", 
                        gripcount=0,
                        background="#001100", 
                        darkcolor="#001100", 
                        lightcolor="#001100",
                        troughcolor="#001100", 
                        bordercolor="#39ff14", 
                        arrowcolor="#39ff14")
        style.map("Vertical.TScrollbar",
                  background=[('pressed', '#39ff14'), ('active', '#004400')],
                  arrowcolor=[('pressed', '#001100'), ('active', '#39ff14')])
        
        # Retro ASCII Title
        tk.Label(self, text="""
  _ RV32I SYSTEM MANAGER _
 |________________________|
        """, bg="#001100", fg="#39ff14", 
                 font=("Consolas", 18, "bold")).pack(pady=(20, 0))
        
        tk.Label(self, text="--- SELECT TEST OR DEPLOY HEX ---", 
                 bg="#001100", fg="#39ff14", font=("Consolas", 10)).pack(pady=(0, 20))
        
        # Main Layout
        content_frame = tk.Frame(self, bg="#001100", highlightbackground="#39ff14", highlightthickness=1)
        content_frame.pack(fill="both", expand=True, padx=40, pady=20)
        
        # Treeview (Left Side)
        tree_frame = tk.Frame(content_frame, bg="#001100")
        tree_frame.pack(side="left", fill="both", expand=True, padx=10, pady=10)
        
        self.tree = ttk.Treeview(tree_frame, selectmode="browse")
        self.tree.pack(side="left", fill="both", expand=True)
        
        scrollbar = ttk.Scrollbar(tree_frame, orient="vertical", command=self.tree.yview)
        scrollbar.pack(side="right", fill="y")
        self.tree.configure(yscrollcommand=scrollbar.set)
        
        self.tree.heading("#0", text="FILE SYSTEM / TESTS", anchor="w")
        
        # Populate Tree
        self.populate_tree()
        self.tree.bind("<<TreeviewSelect>>", self.on_select)
        
        # Buttons (Right Side)
        btn_frame = tk.Frame(content_frame, bg="#001100")
        btn_frame.pack(side="right", fill="y", padx=20, pady=20)
        
        def create_retro_btn(parent, text, cmd, state="normal"):
            return tk.Button(parent, text=text, command=cmd, state=state,
                             bg="#001100", fg="#39ff14", 
                             activebackground="#39ff14", activeforeground="#001100",
                             disabledforeground="#002200",
                             font=("Consolas", 11, "bold"),
                             relief="flat", bd=1, highlightthickness=1,
                             highlightbackground="#39ff14",
                             width=25, height=2)

        self.deploy_btn = create_retro_btn(btn_frame, "[ DEPLOY TO FPGA ]", self.deploy_hex, state="disabled")
        self.deploy_btn.pack(pady=10)
        
        self.view_btn = create_retro_btn(btn_frame, "[ VIEW TRACE (CSV) ]", self.view_csv, state="disabled")
        self.view_btn.pack(pady=10)
        
        self.arch_btn = create_retro_btn(btn_frame, "[ HARDWARE ARCH ]", self.show_arch)
        self.arch_btn.pack(pady=10)
        
        self.exit_btn = create_retro_btn(btn_frame, "[ TERMINATE ]", sys.exit)
        self.exit_btn.pack(pady=10)

    def populate_tree(self):
        # Start scanning from the script's directory
        self._add_to_tree(self.script_dir, "")

    def _add_to_tree(self, path, parent_node):
        try:
            items = sorted(os.listdir(path))
        except:
            return

        for item in items:
            if item.startswith(".") or item == "vga_viewer.py" or item == "FPGA_TEST_GUIDE.md":
                continue
                
            full_path = os.path.join(path, item)
            is_dir = os.path.isdir(full_path)
            
            node = self.tree.insert(parent_node, "end", text=item, 
                                   values=(full_path, "dir" if is_dir else "file"),
                                   open=False)
            
            if is_dir:
                self._add_to_tree(full_path, node)

    def on_select(self, event):
        selected = self.tree.selection()
        if not selected:
            return
            
        item = self.tree.item(selected[0])
        path, type = item["values"]
        
        # Reset buttons
        self.deploy_btn.config(state="disabled")
        self.view_btn.config(state="disabled")
        
        if type == "file":
            if path.endswith(".hex"):
                self.deploy_btn.config(state="normal")
            elif path.endswith(".csv"):
                self.view_btn.config(state="normal")

    def deploy_hex(self):
        selected = self.tree.selection()
        path = self.tree.item(selected[0])["values"][0]
        dest = os.path.join(self.root_dir, "program.hex")
        
        try:
            shutil.copy2(path, dest)
            messagebox.showinfo("Success", f"Deployed {os.path.basename(path)} to:\n{dest}\n\nYou can now compile in Quartus.")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to deploy:\n{str(e)}")

    def view_csv(self):
        selected = self.tree.selection()
        path = self.tree.item(selected[0])["values"][0]
        self.controller.open_viewer(path)

    def show_arch(self):
        svg_path = os.path.join(self.root_dir, "docs", "hardware_architecture.svg")
        if os.path.exists(svg_path):
            if sys.platform.startswith('win'):
                os.startfile(svg_path)
            elif sys.platform.startswith('darwin'):
                subprocess.call(('open', svg_path))
            else:
                subprocess.call(('xdg-open', svg_path))
        else:
            messagebox.showerror("Error", f"Architecture diagram not found at:\n{svg_path}")

class VGAPipBoyViewer(tk.Frame):
    def __init__(self, parent, controller, csv_data):
        super().__init__(parent, bg="#001100")
        self.controller = controller
        self.csv_data = csv_data
        self.current_step = 0
        self.max_step = len(csv_data) - 1

        # 80x30 text area
        self.text_area = tk.Text(
            self, 
            width=80, 
            height=30, 
            bg="#002200", 
            fg="#39ff14", 
            font=("Consolas", 12, "bold"), # Reduced font slightly
            state="disabled",
            relief="flat",
            padx=10,
            pady=5
        )
        self.text_area.pack(pady=10)
        
        # Controls Frame (Horizontal)
        controls_frame = tk.Frame(self, bg="#001100")
        controls_frame.pack(fill="x", padx=40)

        # Back Button
        tk.Button(
            self, 
            text="[ BACK TO MENU ]", 
            command=self.controller.show_menu,
            bg="#001100", fg="#39ff14", 
            activebackground="#39ff14", activeforeground="#001100",
            font=("Consolas", 10, "bold"),
            relief="flat", bd=1, highlightthickness=1,
            highlightbackground="#39ff14",
            width=20
        ).pack(pady=10)

        # Control Label (Center/Right)
        tk.Label(
            controls_frame, 
            text="< LEFT : Backward | RIGHT : Forward >", 
            bg="#001100", 
            fg="#39ff14", 
            font=("Consolas", 10, "bold")
        ).pack(side="right", pady=10)

        # Bind Keys (must focus the frame)
        self.bind_all("<Right>", self.step_forward)
        self.bind_all("<Left>", self.step_backward)
        
        self.render_screen()

    def step_forward(self, event):
        if self.current_step < self.max_step:
            self.current_step += 1
            self.render_screen()

    def step_backward(self, event):
        if self.current_step > 0:
            self.current_step -= 1
            self.render_screen()

    def render_screen(self):
        row_data = self.csv_data[self.current_step]
        
        if row_data[0].startswith("---"):
            content = [" " * 80 for _ in range(30)]
            msg = "ROLLBACK INITIATED"
            content[14] = msg.center(80)
            self._update_text(content)
            return

        pc = row_data[1]
        inst_hex = row_data[2]
        alu_res = row_data[3]
        rs1 = row_data[4]
        rs2 = row_data[5]
        regs = row_data[6:38]
        if len(regs) < 32: regs = ["OFF"] * 32

        lines = []
        lines.append("+" + "-"*78 + "+")
        header_text = f" RV32I HARDWARE MONITOR | STEP: {self.current_step}/{self.max_step} "
        lines.append("|" + header_text.center(78) + "|")
        lines.append("|" + " "*78 + "|")
        lines.append("|  " + f" PC: {pc} ".ljust(35) + f" INST: {inst_hex} ".ljust(41) + "|")
        lines.append("|  " + f" ALU_RES: {alu_res} ".ljust(35) + f" rs1: {rs1}   rs2: {rs2} ".ljust(41) + "|")
        lines.append("|" + " "*78 + "|")
        lines.append("|" + " --- REGISTERS ".ljust(78, "-") + "|")
        lines.append("|" + " "*78 + "|")
        
        for i in range(8):
            row_str = " |  "
            for col in range(4):
                reg_idx = i + (col * 8)
                val = regs[reg_idx] if reg_idx < len(regs) else "OFF"
                row_str += f"x{reg_idx}".ljust(3) + f":{val}    "
            lines.append(row_str.ljust(79) + "|")
            
        lines.append("|" + " "*78 + "|")
        lines.append("|" + " --- DECODED ASSEMBLY ".ljust(78, "-") + "|")
        lines.append("|" + " "*78 + "|")
        lines.append("|" + f" > {row_data[0]} ".center(78) + "|")
        
        while len(lines) < 29: lines.append("|" + " "*78 + "|")
        lines.append("+" + "-"*78 + "+")
        self._update_text(lines)

    def _update_text(self, lines):
        self.text_area.config(state="normal")
        self.text_area.delete("1.0", tk.END)
        self.text_area.insert("1.0", "\n".join(lines))
        self.text_area.config(state="disabled")

if __name__ == "__main__":
    app = RV32IManager()
    app.mainloop()
