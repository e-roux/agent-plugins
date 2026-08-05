#!/usr/bin/env uv run

import ast
import sys
import argparse
import json
import subprocess
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

class AnnotationAnalytic:
    def __init__(self, filepath: str, context: str, elem_type: str, annotation_str: str, length: int):
        self.filepath = filepath
        self.context = context
        self.elem_type = elem_type
        self.annotation_str = annotation_str
        self.length = length

    def to_dict(self) -> Dict[str, Any]:
        return {
            "filepath": self.filepath,
            "context": self.context,
            "type": self.elem_type,
            "annotation": self.annotation_str,
            "length": self.length,
        }

def is_docstring_node(node: ast.AST) -> bool:
    return (
        isinstance(node, ast.Expr) and
        isinstance(node.value, ast.Constant) and
        isinstance(node.value.value, str)
    )

class TypeAnnotationStripper(ast.NodeTransformer):
    def __init__(self, filepath: str, strip_docstrings: bool = False):
        super().__init__()
        self.filepath = filepath
        self.context_stack = []
        self.analytics = []
        self.strip_docstrings = strip_docstrings

    def get_current_context(self) -> str:
        return ".".join(self.context_stack) if self.context_stack else "<module>"

    def record_annotation(self, node: ast.AST, elem_type: str):
        try:
            annot_str = ast.unparse(node)
            length = len(annot_str)
            self.analytics.append(AnnotationAnalytic(
                filepath=self.filepath,
                context=self.get_current_context(),
                elem_type=elem_type,
                annotation_str=annot_str,
                length=length
            ))
        except Exception:
            pass

    def record_type_comment(self, comment_str: str, elem_type: str):
        self.analytics.append(AnnotationAnalytic(
            filepath=self.filepath,
            context=self.get_current_context(),
            elem_type=elem_type,
            annotation_str=f"type: {comment_str}",
            length=len(comment_str) + 6
        ))

    def handle_docstring(self, node_body: list, context_name: str):
        if node_body and is_docstring_node(node_body[0]):
            doc_str = node_body[0].value.value
            doc_len = len(doc_str)
            self.analytics.append(AnnotationAnalytic(
                filepath=self.filepath,
                context=self.get_current_context(),
                elem_type="Docstring",
                annotation_str=f'"""{doc_str[:30].replace("\n", " ")}..."""' if len(doc_str) > 30 else f'"""{doc_str}"""',
                length=doc_len
            ))
            if self.strip_docstrings:
                node_body.pop(0)

    def visit_Module(self, node: ast.Module) -> Any:
        self.handle_docstring(node.body, "<module>")
        return self.generic_visit(node)

    def visit_ClassDef(self, node: ast.ClassDef) -> Any:
        self.context_stack.append(node.name)
        self.handle_docstring(node.body, node.name)
        if hasattr(node, "type_params") and node.type_params:
            for tp in node.type_params:
                # Handle PEP 695 generic parameter bounds
                if hasattr(tp, "bound") and tp.bound:
                    self.record_annotation(tp.bound, f"TypeVar '{tp.name}' bound")
                    if not self.strip_docstrings: # keep structure unless stripping
                        tp.bound = None
        node = self.generic_visit(node)
        self.context_stack.pop()
        return node

    def visit_FunctionDef(self, node: ast.FunctionDef) -> Any:
        self.context_stack.append(node.name)
        self.handle_docstring(node.body, node.name)
        if hasattr(node, "type_params") and node.type_params:
            for tp in node.type_params:
                if hasattr(tp, "bound") and tp.bound:
                    self.record_annotation(tp.bound, f"TypeVar '{tp.name}' bound")
                    tp.bound = None
        if node.returns:
            self.record_annotation(node.returns, "Return")
            node.returns = None
        args_list = []
        if hasattr(node.args, "posonlyargs"):
            args_list.extend(node.args.posonlyargs)
        args_list.extend(node.args.args)
        args_list.extend(node.args.kwonlyargs)
        for arg in args_list:
            if arg.annotation:
                self.record_annotation(arg.annotation, f"Parameter '{arg.arg}'")
                arg.annotation = None
        if node.args.vararg and node.args.vararg.annotation:
            self.record_annotation(node.args.vararg.annotation, f"Parameter '*{node.args.vararg.arg}'")
            node.args.vararg.annotation = None
        if node.args.kwarg and node.args.kwarg.annotation:
            self.record_annotation(node.args.kwarg.annotation, f"Parameter '**{node.args.kwarg.arg}'")
            node.args.kwarg.annotation = None
        if hasattr(node, "type_comment") and node.type_comment:
            self.record_type_comment(node.type_comment, "Function Type Comment")
            node.type_comment = None
        node = self.generic_visit(node)
        self.context_stack.pop()
        return node

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> Any:
        return self.visit_FunctionDef(node)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> Any:
        target_str = ast.unparse(node.target)
        self.record_annotation(node.annotation, f"Variable '{target_str}'")
        if node.value is None:
            return None
        new_node = ast.Assign(targets=[node.target], value=node.value)
        ast.copy_location(new_node, node)
        return new_node

    def visit_Assign(self, node: ast.Assign) -> Any:
        if hasattr(node, "type_comment") and node.type_comment:
            self.record_type_comment(node.type_comment, "Assignment Type Comment")
            node.type_comment = None
        return self.generic_visit(node)

    # Support modern PEP 695 TypeAlias statements (Python 3.12+)
    def visit_TypeAlias(self, node: ast.TypeAlias) -> Any:
        name_str = ast.unparse(node.name)
        self.record_annotation(node.value, f"TypeAlias '{name_str}'")
        return self.generic_visit(node)

    def visit_For(self, node: ast.For) -> Any:
        if hasattr(node, "type_comment") and node.type_comment:
            self.record_type_comment(node.type_comment, "For Loop Type Comment")
            node.type_comment = None
        return self.generic_visit(node)

    def visit_AsyncFor(self, node: ast.AsyncFor) -> Any:
        if hasattr(node, "type_comment") and node.type_comment:
            self.record_type_comment(node.type_comment, "Async For Loop Type Comment")
            node.type_comment = None
        return self.generic_visit(node)

    def visit_With(self, node: ast.With) -> Any:
        if hasattr(node, "type_comment") and node.type_comment:
            self.record_type_comment(node.type_comment, "With Statement Type Comment")
            node.type_comment = None
        return self.generic_visit(node)

    def visit_AsyncWith(self, node: ast.AsyncWith) -> Any:
        if hasattr(node, "type_comment") and node.type_comment:
            self.record_type_comment(node.type_comment, "Async With Statement Type Comment")
            node.type_comment = None
        return self.generic_visit(node)

def process_file(
    file_path: Path,
    inplace: bool = False,
    output_path: Optional[Path] = None,
    no_strip: bool = False,
    strip_docstrings: bool = False
) -> Tuple[str, List[AnnotationAnalytic], int]:
    try:
        source_code = file_path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"Error reading file {file_path}: {e}", file=sys.stderr)
        return "", [], 0

    original_length = len(source_code)
    try:
        tree = ast.parse(source_code, filename=str(file_path), type_comments=True)
    except SyntaxError as e:
        print(f"Syntax error parsing {file_path}: {e}", file=sys.stderr)
        return source_code, [], original_length

    stripper = TypeAnnotationStripper(str(file_path), strip_docstrings=strip_docstrings)
    stripped_tree = stripper.visit(tree)
    ast.fix_missing_locations(stripped_tree)

    try:
        unannotated_code = ast.unparse(stripped_tree)
    except Exception as e:
        print(f"Error unparsing AST for {file_path}: {e}", file=sys.stderr)
        unannotated_code = source_code

    if not no_strip:
        if inplace:
            try:
                file_path.write_text(unannotated_code, encoding="utf-8")
                # Trigger ruff format or black format if available
                if subprocess.run(["command", "-v", "ruff"], capture_output=True).returncode == 0:
                    subprocess.run(["ruff", "format", str(file_path)], capture_output=True)
                elif subprocess.run(["command", "-v", "black"], capture_output=True).returncode == 0:
                    subprocess.run(["black", str(file_path)], capture_output=True)
            except Exception as e:
                print(f"Error overwriting {file_path} in-place: {e}", file=sys.stderr)
        elif output_path:
            try:
                output_path.write_text(unannotated_code, encoding="utf-8")
            except Exception as e:
                print(f"Error writing to output path {output_path}: {e}", file=sys.stderr)

    return unannotated_code, stripper.analytics, original_length

def find_python_files(path: Path) -> List[Path]:
    if path.is_file():
        return [path] if path.suffix == ".py" else []
    python_files = []
    for p in path.rglob("*.py"):
        if any(part.startswith(".") for part in p.parts):
            continue
        python_files.append(p)
    return sorted(python_files)

def draw_table(title: str, headers: List[str], rows: List[List[str]]):
    widths = [len(h) for h in headers]
    for row in rows:
        for i, val in enumerate(row):
            widths[i] = max(widths[i], len(val))
    border = "+" + "+".join("-" * (w + 2) for w in widths) + "+"
    header_line = "|" + "|".join(f" {h.ljust(w)} " for h, w in zip(headers, widths)) + "|"
    print()
    print("=" * (sum(widths) + len(widths) * 3 + 1))
    print(title.center(sum(widths) + len(widths) * 3 + 1))
    print("=" * (sum(widths) + len(widths) * 3 + 1))
    print(border)
    print(header_line)
    print(border.replace("-", "="))
    for row in rows:
        row_line = "|" + "|".join(f" {val.ljust(w)} " for val, w in zip(row, widths)) + "|"
        print(row_line)
    print(border)

def draw_panel(title: str, content: List[str]):
    max_len = len(title)
    for line in content:
        max_len = max(max_len, len(line))
    border = "+" + "-" * (max_len + 4) + "+"
    print()
    print(border)
    print(f"|  {title.center(max_len)}  |")
    print("+" + "=" * (max_len + 4) + "+")
    for line in content:
        print(f"|  {line.ljust(max_len)}  |")
    print(border)

def main():
    parser = argparse.ArgumentParser(
        description="Strip Python Type Annotations/Docstrings and Provide High-Fidelity Structural Analytics."
    )
    parser.add_argument("path", help="The file or directory path to process.")
    parser.add_argument(
        "-i", "--inplace", action="store_true",
        help="Overwrite target files with unannotated/uncommented code."
    )
    parser.add_argument(
        "-o", "--output", type=str, default=None,
        help="File path to save the unannotated output (only valid for a single file)."
    )
    parser.add_argument(
        "--no-strip", action="store_true",
        help="Run analysis only; do not write or print unannotated code."
    )
    parser.add_argument(
        "--strip-docstrings", action="store_true",
        help="Additionally strip all module, class, and function docstrings."
    )
    parser.add_argument(
        "-f", "--format", choices=["text", "json"], default="text",
        help="The output format for the analytics (default: text)."
    )
    parser.add_argument(
        "--verbose", action="store_true",
        help="Print every single stripped annotation/docstring (default: summary table)."
    )
    args = parser.parse_args()
    input_path = Path(args.path)
    if not input_path.exists():
        print(f"Error: Path '{input_path}' does not exist.", file=sys.stderr)
        sys.exit(1)
    python_files = find_python_files(input_path)
    if not python_files:
        print("No Python (.py) files found at the target path.", file=sys.stderr)
        sys.exit(0)
    if args.output and len(python_files) > 1:
        print("Error: --output can only be used with a single input file.", file=sys.stderr)
        sys.exit(1)
    all_analytics = []
    total_original_chars = 0
    total_annot_chars = 0
    total_docstring_chars = 0
    files_processed = 0
    last_unannotated_code = ""
    for file_path in python_files:
        out_path = Path(args.output) if args.output else None
        unannot_code, file_analytics, orig_len = process_file(
            file_path=file_path,
            inplace=args.inplace,
            output_path=out_path,
            no_strip=args.no_strip,
            strip_docstrings=args.strip_docstrings
        )
        all_analytics.extend(file_analytics)
        total_original_chars += orig_len
        total_annot_chars += sum(a.length for a in file_analytics if a.elem_type != "Docstring")
        total_docstring_chars += sum(a.length for a in file_analytics if a.elem_type == "Docstring")
        files_processed += 1
        last_unannotated_code = unannot_code
    if len(python_files) == 1 and not args.inplace and not args.output and not args.no_strip:
        if args.format == "text":
            print("--- STRIPPED PYTHON CODE ---")
            print(last_unannotated_code)
            print("--- END OF STRIPPED CODE ---\n")
    density = (total_annot_chars / total_original_chars * 100) if total_original_chars > 0 else 0.0
    docstring_density = (total_docstring_chars / total_original_chars * 100) if total_original_chars > 0 else 0.0
    if args.format == "json":
        json_output = {
            "summary": {
                "files_processed": files_processed,
                "total_original_chars": total_original_chars,
                "total_annotation_chars": total_annot_chars,
                "total_docstring_chars": total_docstring_chars,
                "annotation_density_percent": round(density, 2),
                "docstring_density_percent": round(docstring_density, 2),
                "total_metadata_found": len(all_analytics),
            },
            "annotations": [a.to_dict() for a in all_analytics]
        }
        if len(python_files) == 1 and not args.inplace and not args.output and not args.no_strip:
            json_output["stripped_code"] = last_unannotated_code
        print(json.dumps(json_output, indent=2))
        return
    if all_analytics:
        headers = ["File", "Scope / Context", "Element Type", "Descriptor (Unparsed)", "Length"]
        rows = []
        max_rows = 40 if not args.verbose else len(all_analytics)
        for analytic in all_analytics[:max_rows]:
            rel_path = analytic.filepath
            try:
                rel_path = str(Path(analytic.filepath).relative_to(Path.cwd()))
            except ValueError:
                pass
            rows.append([
                rel_path,
                analytic.context,
                analytic.elem_type,
                analytic.annotation_str,
                str(analytic.length)
            ])
        draw_table("Stripped Code Descriptors & Analytics", headers, rows)
        if len(all_analytics) > max_rows:
            print(f"... and {len(all_analytics) - max_rows} more descriptors. Pass --verbose to list all.\n")
    summary_text = [
        f"Files Processed:             {files_processed}",
        f"Total Structural Elements:   {len(all_analytics)}",
        f"Original Code Size:          {total_original_chars} characters",
        f"Annotation Footprint:        {total_annot_chars} characters ({density:.2f}%)",
        f"Docstring Footprint:         {total_docstring_chars} characters ({docstring_density:.2f}%)"
    ]
    draw_panel("Codebase Static-Metadata Summary", summary_text)

if __name__ == "__main__":
    main()
