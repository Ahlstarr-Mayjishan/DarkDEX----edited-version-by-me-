#!/usr/bin/env python3
import json
import re
import sys
from collections import Counter


RESERVED = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
    "until", "while", "self", "game", "workspace", "script", "local", "return",
}

SIGNALS = {
    "remote_calls": [r"\bFireServer\s*\(", r"\bInvokeServer\s*\(", r"\bOnClientEvent\b", r"\bOnClientInvoke\b"],
    "dynamic_code": [r"\bloadstring\s*\(", r"\bgetfenv\b", r"\bsetfenv\b"],
    "http": [r"\bHttpGet\b", r"\bHttpPost\b", r"\brequest\s*\("],
    "filesystem": [r"\bfile_exists\b", r"\breadfile\s*\(", r"\bwritefile\s*\(", r"\bappendfile\s*\("],
    "hooks": [r"\bhookfunction\b", r"\bhookmetamethod\b", r"\bgetrawmetatable\b"],
    "gc_debug": [r"\bgetgc\b", r"\bgetconnections\b", r"\bdebug\."],
}


def count_patterns(source, patterns):
    return sum(len(re.findall(pattern, source)) for pattern in patterns)


def top_identifiers(source, limit=16):
    words = re.findall(r"[A-Za-z_][A-Za-z0-9_]{2,}", source)
    counts = Counter(word for word in words if word.lower() not in RESERVED)
    return [{"name": name, "count": count} for name, count in counts.most_common(limit)]


# --- Pure-Python Lexer ---

class Token:
    def __init__(self, type_, value, line):
        self.type = type_
        self.value = value
        self.line = line

    def __repr__(self):
        return f"Token({self.type}, {self.value!r}, line {self.line})"


def lex(source):
    tokens = []
    line = 1
    pos = 0
    length = len(source)

    while pos < length:
        ch = source[pos]

        if ch == '\n':
            line += 1
            pos += 1
            continue
        elif ch.isspace():
            pos += 1
            continue

        # Comments
        if ch == '-' and pos + 1 < length and source[pos+1] == '-':
            pos += 2
            # Check if multi-line comment: --[[ ... ]]
            if pos + 1 < length and source[pos:pos+2] == '[[':
                pos += 2
                while pos < length:
                    if source[pos] == '\n':
                        line += 1
                    if pos + 1 < length and source[pos:pos+2] == ']]':
                        pos += 2
                        break
                    pos += 1
                else:
                    break
            else:
                while pos < length and source[pos] != '\n':
                    pos += 1
            continue

        # Multi-line strings: [[ ... ]]
        if ch == '[' and pos + 1 < length and source[pos+1] == '[':
            start_line = line
            pos += 2
            start = pos
            while pos < length:
                if source[pos] == '\n':
                    line += 1
                if pos + 1 < length and source[pos:pos+2] == ']]':
                    val = source[start:pos]
                    pos += 2
                    break
                pos += 1
            else:
                val = source[start:]
            tokens.append(Token("STRING", val, start_line))
            continue

        # Standard strings
        if ch in ('"', "'"):
            quote = ch
            start_line = line
            pos += 1
            start = pos
            val = []
            while pos < length:
                c = source[pos]
                if c == '\n':
                    line += 1
                if c == '\\':
                    if pos + 1 < length:
                        val.append(source[pos:pos+2])
                        pos += 2
                        continue
                if c == quote:
                    pos += 1
                    break
                val.append(c)
                pos += 1
            tokens.append(Token("STRING", "".join(val), start_line))
            continue

        # Hex Numbers
        if ch == '0' and pos + 1 < length and source[pos+1] in ('x', 'X'):
            start = pos
            pos += 2
            while pos < length and (source[pos].isdigit() or source[pos].lower() in 'abcdef'):
                pos += 1
            tokens.append(Token("NUMBER", source[start:pos], line))
            continue

        # Decimal / Float Numbers
        if ch.isdigit() or (ch == '.' and pos + 1 < length and source[pos+1].isdigit()):
            start = pos
            has_dot = (ch == '.')
            if has_dot:
                pos += 2
            else:
                pos += 1
            while pos < length:
                c = source[pos]
                if c == '.':
                    if has_dot:
                        break
                    has_dot = True
                    pos += 1
                elif c.isdigit():
                    pos += 1
                elif c.lower() == 'e':
                    pos += 1
                    if pos < length and source[pos] in ('+', '-'):
                        pos += 1
                    while pos < length and source[pos].isdigit():
                        pos += 1
                    break
                else:
                    break
            tokens.append(Token("NUMBER", source[start:pos], line))
            continue

        # Identifiers
        if ch.isalpha() or ch == '_':
            start = pos
            pos += 1
            while pos < length and (source[pos].isalnum() or source[pos] == '_'):
                pos += 1
            val = source[start:pos]
            if val in ("and", "break", "do", "else", "elseif", "end", "false", "for", "function",
                       "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
                       "until", "while"):
                tokens.append(Token("KEYWORD", val, line))
            else:
                tokens.append(Token("NAME", val, line))
            continue

        # Symbols
        if pos + 1 < length:
            two = source[pos:pos+2]
            if two in ("==", "~=", "<=", ">=", "..", "::", "+=", "-=", "*=", "/="):
                tokens.append(Token("SYMBOL", two, line))
                pos += 2
                continue

        tokens.append(Token("SYMBOL", ch, line))
        pos += 1

    return tokens


# --- Simplified AST Nodes ---

class ASTNode:
    def __init__(self, type_, line):
        self.type = type_
        self.line = line


class Literal(ASTNode):
    def __init__(self, value, raw_type, line):
        super().__init__("Literal", line)
        self.value = value
        self.raw_type = raw_type


class Identifier(ASTNode):
    def __init__(self, name, line):
        super().__init__("Identifier", line)
        self.name = name


class Call(ASTNode):
    def __init__(self, func, args, line):
        super().__init__("Call", line)
        self.func = func
        self.args = args


class Index(ASTNode):
    def __init__(self, obj, key, is_dot, line):
        super().__init__("Index", line)
        self.obj = obj
        self.key = key
        self.is_dot = is_dot


class Assign(ASTNode):
    def __init__(self, targets, values, is_local, line):
        super().__init__("Assign", line)
        self.targets = targets
        self.values = values
        self.is_local = is_local


class BinOp(ASTNode):
    def __init__(self, left, op, right, line):
        super().__init__("BinOp", line)
        self.left = left
        self.op = op
        self.right = right


class Table(ASTNode):
    def __init__(self, fields, line):
        super().__init__("Table", line)
        self.fields = fields


class If(ASTNode):
    def __init__(self, cond, then_block, else_block, line):
        super().__init__("If", line)
        self.cond = cond
        self.then_block = then_block
        self.else_block = else_block


class While(ASTNode):
    def __init__(self, cond, body, line):
        super().__init__("While", line)
        self.cond = cond
        self.body = body


class Repeat(ASTNode):
    def __init__(self, body, cond, line):
        super().__init__("Repeat", line)
        self.body = body
        self.cond = cond


class ForNum(ASTNode):
    def __init__(self, var_name, start, limit, step, body, line):
        super().__init__("ForNum", line)
        self.var_name = var_name
        self.start = start
        self.limit = limit
        self.step = step
        self.body = body


class ForIn(ASTNode):
    def __init__(self, var_names, exprs, body, line):
        super().__init__("ForIn", line)
        self.var_names = var_names
        self.exprs = exprs
        self.body = body


class DoBlock(ASTNode):
    def __init__(self, body, line):
        super().__init__("DoBlock", line)
        self.body = body


class FunctionDef(ASTNode):
    def __init__(self, name, params, body, is_local, line):
        super().__init__("FunctionDef", line)
        self.name = name
        self.params = params
        self.body = body
        self.is_local = is_local


class Return(ASTNode):
    def __init__(self, values, line):
        super().__init__("Return", line)
        self.values = values


class Break(ASTNode):
    def __init__(self, line):
        super().__init__("Break", line)


# --- Simplified AST Parser ---

class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0
        self.length = len(tokens)

    def peek(self, offset=0):
        idx = self.pos + offset
        if idx < self.length:
            return self.tokens[idx]
        return None

    def advance(self):
        tok = self.peek()
        if tok:
            self.pos += 1
        return tok

    def match(self, type_, value=None):
        tok = self.peek()
        if tok and tok.type == type_:
            if value is None or tok.value == value:
                self.pos += 1
                return tok
        return None

    def parse(self):
        return self.parse_block()

    def parse_block(self):
        body = []
        while self.pos < self.length:
            tok = self.peek()
            if not tok:
                break
            if tok.type == "KEYWORD" and tok.value in ("end", "else", "elseif", "until"):
                break
            stmt = self.parse_statement()
            if stmt:
                body.append(stmt)
            else:
                self.advance()
        return body

    def parse_statement(self):
        tok = self.peek()
        if not tok:
            return None

        # Semicolon
        if tok.type == "SYMBOL" and tok.value == ";":
            self.advance()
            return None

        # local ...
        if tok.type == "KEYWORD" and tok.value == "local":
            line = tok.line
            self.advance()
            if self.match("KEYWORD", "function"):
                name_tok = self.match("NAME")
                if name_tok:
                    name_node = Identifier(name_tok.value, name_tok.line)
                    params = self.parse_parameters()
                    body = self.parse_block()
                    self.match("KEYWORD", "end")
                    return FunctionDef(name_node, params, body, is_local=True, line=line)
                return None

            names = []
            while True:
                name_tok = self.match("NAME")
                if name_tok:
                    names.append(Identifier(name_tok.value, name_tok.line))
                else:
                    break
                if not self.match("SYMBOL", ","):
                    break

            if self.match("SYMBOL", ":"):
                self.skip_type_annotation()

            values = []
            if self.match("SYMBOL", "="):
                values = self.parse_expression_list()

            return Assign(names, values, True, line)

        # function ...
        if tok.type == "KEYWORD" and tok.value == "function":
            line = tok.line
            self.advance()
            name_node = self.parse_primary_expression()
            params = self.parse_parameters()
            body = self.parse_block()
            self.match("KEYWORD", "end")
            return FunctionDef(name_node, params, body, is_local=False, line=line)

        # if ...
        if tok.type == "KEYWORD" and tok.value == "if":
            return self.parse_if_statement()

        # while ...
        if tok.type == "KEYWORD" and tok.value == "while":
            return self.parse_while_statement()

        # repeat ...
        if tok.type == "KEYWORD" and tok.value == "repeat":
            return self.parse_repeat_statement()

        # do ...
        if tok.type == "KEYWORD" and tok.value == "do":
            return self.parse_do_statement()

        # for ...
        if tok.type == "KEYWORD" and tok.value == "for":
            return self.parse_for_statement()

        # return ...
        if tok.type == "KEYWORD" and tok.value == "return":
            return self.parse_return_statement()

        # break ...
        if tok.type == "KEYWORD" and tok.value == "break":
            return self.parse_break_statement()

        expr_list = self.parse_expression_list()
        if not expr_list:
            return None

        if self.match("SYMBOL", "="):
            values = self.parse_expression_list()
            return Assign(expr_list, values, False, expr_list[0].line)

        return expr_list[0]

    def parse_if_statement(self):
        line = self.peek().line
        self.advance() # 'if'
        cond = self.parse_expression()
        self.match("KEYWORD", "then")
        then_block = self.parse_block()
        
        current_if = If(cond, then_block, [], line)
        root_if = current_if
        
        while True:
            tok = self.peek()
            if not tok:
                break
            if tok.type == "KEYWORD" and tok.value == "elseif":
                elseif_line = tok.line
                self.advance() # 'elseif'
                elseif_cond = self.parse_expression()
                self.match("KEYWORD", "then")
                elseif_then = self.parse_block()
                
                new_if = If(elseif_cond, elseif_then, [], elseif_line)
                current_if.else_block = [new_if]
                current_if = new_if
            elif tok.type == "KEYWORD" and tok.value == "else":
                self.advance() # 'else'
                else_body = self.parse_block()
                current_if.else_block = else_body
                break
            elif tok.type == "KEYWORD" and tok.value == "end":
                break
            else:
                break
                
        self.match("KEYWORD", "end")
        return root_if

    def parse_while_statement(self):
        line = self.peek().line
        self.advance() # 'while'
        cond = self.parse_expression()
        self.match("KEYWORD", "do")
        body = self.parse_block()
        self.match("KEYWORD", "end")
        return While(cond, body, line)

    def parse_repeat_statement(self):
        line = self.peek().line
        self.advance() # 'repeat'
        body = self.parse_block()
        self.match("KEYWORD", "until")
        cond = self.parse_expression()
        return Repeat(body, cond, line)

    def parse_do_statement(self):
        line = self.peek().line
        self.advance() # 'do'
        body = self.parse_block()
        self.match("KEYWORD", "end")
        return DoBlock(body, line)

    def parse_for_statement(self):
        line = self.peek().line
        self.advance() # 'for'
        
        names = []
        name_tok = self.match("NAME")
        if name_tok:
            names.append(Identifier(name_tok.value, name_tok.line))
        else:
            return None
            
        tok = self.peek()
        if tok and tok.type == "SYMBOL" and tok.value == "=":
            self.advance() # '='
            start = self.parse_expression()
            self.match("SYMBOL", ",")
            limit = self.parse_expression()
            step = None
            if self.match("SYMBOL", ","):
                step = self.parse_expression()
            self.match("KEYWORD", "do")
            body = self.parse_block()
            self.match("KEYWORD", "end")
            return ForNum(names[0], start, limit, step, body, line)
        else:
            while self.match("SYMBOL", ","):
                n_tok = self.match("NAME")
                if n_tok:
                    names.append(Identifier(n_tok.value, n_tok.line))
            self.match("KEYWORD", "in")
            exprs = self.parse_expression_list()
            self.match("KEYWORD", "do")
            body = self.parse_block()
            self.match("KEYWORD", "end")
            return ForIn(names, exprs, body, line)

    def parse_return_statement(self):
        line = self.peek().line
        self.advance() # 'return'
        exprs = []
        tok = self.peek()
        if tok and not (tok.type == "KEYWORD" and tok.value in ("end", "else", "elseif", "until")):
            if tok.type != "SYMBOL" or tok.value not in (")", "}", "]", ";"):
                exprs = self.parse_expression_list()
        self.match("SYMBOL", ";")
        return Return(exprs, line)

    def parse_break_statement(self):
        line = self.peek().line
        self.advance() # 'break'
        return Break(line)

    def parse_parameters(self):
        self.match("SYMBOL", "(")
        params = []
        while True:
            tok = self.peek()
            if not tok:
                break
            if tok.type == "SYMBOL" and tok.value == ")":
                break
            if tok.type == "NAME":
                name_node = Identifier(tok.value, tok.line)
                params.append(name_node)
                self.advance()
                if self.match("SYMBOL", ":"):
                    self.skip_type_annotation()
            elif tok.type == "SYMBOL" and tok.value == "...":
                params.append(Identifier("...", tok.line))
                self.advance()
                if self.match("SYMBOL", ":"):
                    self.skip_type_annotation()
            
            if not self.match("SYMBOL", ","):
                break
        self.match("SYMBOL", ")")
        if self.match("SYMBOL", ":"):
            self.skip_type_annotation()
        return params

    def parse_table_constructor(self):
        line = self.peek().line
        self.advance() # '{'
        fields = []
        while True:
            tok = self.peek()
            if not tok:
                break
            if tok.type == "SYMBOL" and tok.value == "}":
                self.advance()
                break
            
            if tok.type == "SYMBOL" and tok.value == "[":
                self.advance()
                key = self.parse_expression()
                self.match("SYMBOL", "]")
                self.match("SYMBOL", "=")
                val = self.parse_expression()
                fields.append((key, val))
            elif tok.type == "NAME" and self.peek(1) and self.peek(1).type == "SYMBOL" and self.peek(1).value == "=":
                key = Identifier(tok.value, tok.line)
                self.advance() # name
                self.advance() # '='
                val = self.parse_expression()
                fields.append((Literal(key.name, "STRING", key.line), val))
            else:
                val = self.parse_expression()
                fields.append((None, val))
                
            if not (self.match("SYMBOL", ",") or self.match("SYMBOL", ";")):
                self.match("SYMBOL", "}")
                break
        return Table(fields, line)

    def skip_type_annotation(self):
        bracket_count = 0
        while self.pos < self.length:
            tok = self.peek()
            if not tok:
                break
            if tok.type == "SYMBOL":
                if tok.value == "=":
                    break
                elif tok.value in ("(", "{", "["):
                    bracket_count += 1
                elif tok.value in (")", "}", "]"):
                    bracket_count -= 1
                    if bracket_count < 0:
                        break
                elif tok.value == "," and bracket_count == 0:
                    break
            elif tok.type == "KEYWORD":
                break
            self.advance()

    def parse_expression_list(self):
        exprs = []
        while True:
            expr = self.parse_expression()
            if expr:
                exprs.append(expr)
            else:
                break
            if not self.match("SYMBOL", ","):
                break
        return exprs

    def parse_expression(self):
        left = self.parse_primary_expression()
        if not left:
            return None

        # Check for binary operators (specifically string concatenation `..`)
        while True:
            tok = self.peek()
            if tok and tok.type == "SYMBOL" and tok.value in ("..", "+", "-", "*", "/"):
                op = tok.value
                self.advance()
                right = self.parse_primary_expression()
                if right:
                    # Constant Folding: string concatenation
                    if op == ".." and left.type == "Literal" and left.raw_type == "STRING" \
                       and right.type == "Literal" and right.raw_type == "STRING":
                        left = Literal(str(left.value) + str(right.value), "STRING", left.line)
                    else:
                        left = BinOp(left, op, right, left.line)
                else:
                    break
            else:
                break
        return left

    def parse_primary_expression(self):
        tok = self.peek()
        if not tok:
            return None

        node = None
        if tok.type == "STRING":
            node = Literal(tok.value, "STRING", tok.line)
            self.advance()
        elif tok.type == "NUMBER":
            node = Literal(tok.value, "NUMBER", tok.line)
            self.advance()
        elif tok.type == "KEYWORD" and tok.value in ("true", "false"):
            node = Literal(tok.value == "true", "BOOLEAN", tok.line)
            self.advance()
        elif tok.type == "KEYWORD" and tok.value == "nil":
            node = Literal(None, "NIL", tok.line)
            self.advance()
        elif tok.type == "KEYWORD" and tok.value == "function":
            line = tok.line
            self.advance()
            params = self.parse_parameters()
            body = self.parse_block()
            self.match("KEYWORD", "end")
            node = FunctionDef(None, params, body, is_local=False, line=line)
        elif tok.type == "NAME":
            node = Identifier(tok.value, tok.line)
            self.advance()
        elif tok.type == "SYMBOL" and tok.value == "(":
            self.advance()
            node = self.parse_expression()
            self.match("SYMBOL", ")")
        elif tok.type == "SYMBOL" and tok.value == "{":
            node = self.parse_table_constructor()

        if not node:
            return None

        while self.pos < self.length:
            suffix_tok = self.peek()
            if not suffix_tok:
                break

            if suffix_tok.type == "SYMBOL":
                if suffix_tok.value == ".":
                    self.advance()
                    key_tok = self.match("NAME")
                    if key_tok:
                        node = Index(node, Literal(key_tok.value, "STRING", key_tok.line), True, suffix_tok.line)
                    else:
                        break
                elif suffix_tok.value == ":":
                    self.advance()
                    method_tok = self.match("NAME")
                    if method_tok:
                        node = Index(node, Literal(method_tok.value, "STRING", method_tok.line), True, suffix_tok.line)
                    else:
                        break
                elif suffix_tok.value == "[":
                    self.advance()
                    key_node = self.parse_expression()
                    self.match("SYMBOL", "]")
                    node = Index(node, key_node, False, suffix_tok.line)
                elif suffix_tok.value == "(":
                    self.advance()
                    args = self.parse_expression_list()
                    self.match("SYMBOL", ")")
                    node = Call(node, args, suffix_tok.line)
                else:
                    break
            elif suffix_tok.type == "STRING":
                self.advance()
                node = Call(node, [Literal(suffix_tok.value, "STRING", suffix_tok.line)], suffix_tok.line)
            elif suffix_tok.type == "SYMBOL" and suffix_tok.value == "{":
                line = suffix_tok.line
                table_node = self.parse_table_constructor()
                node = Call(node, [table_node], line)
            else:
                break

        return node


# --- AST Traversal & Auditor ---

class Scope:
    def __init__(self, parent=None):
        self.parent = parent
        self.symbols = {}

    def lookup(self, name):
        if name in self.symbols:
            return self.symbols[name]
        if self.parent:
            return self.parent.lookup(name)
        return None

    def define(self, name, node):
        self.symbols[name] = node

    def update(self, name, node):
        if name in self.symbols:
            self.symbols[name] = node
            return True
        if self.parent:
            if self.parent.update(name, node):
                return True
        self.symbols[name] = node
        return False


def resolve_symbol(node, scope, visited=None):
    if not node:
        return None
    if node.type == "Identifier":
        if visited is None:
            visited = set()
        if node.name in visited:
            return node
        visited.add(node.name)
        resolved = scope.lookup(node.name)
        if resolved:
            return resolve_symbol(resolved, scope, visited)
        return node
    elif node.type == "Index":
        resolved_obj = resolve_symbol(node.obj, scope, visited)
        if resolved_obj and resolved_obj.type == "Table":
            if node.key.type == "Literal" and node.key.raw_type == "STRING":
                key_name = node.key.value
                for field_key, field_val in resolved_obj.fields:
                    if field_key and field_key.type == "Literal" and field_key.raw_type == "STRING" and field_key.value == key_name:
                        return resolve_symbol(field_val, scope, visited)
        return Index(resolved_obj, node.key, node.is_dot, node.line)
    return node


def traverse_and_audit(node, findings, scope=None):
    if not node:
        return

    if scope is None:
        scope = Scope()
        # Seed standard global functions as identifiers pointing to themselves so we resolve them correctly
        for glob in ("loadstring", "require", "hookfunction", "hookmetamethod", "getrawmetatable", "setreadonly"):
            scope.define(glob, Identifier(glob, 1))

    if isinstance(node, list):
        for n in node:
            traverse_and_audit(n, findings, scope)
        return

    # --- Phase 1: Audit Rules & Scope Resolution ---
    if node.type == "Assign":
        for i, target in enumerate(node.targets):
            if i < len(node.values):
                val_node = node.values[i]
                resolved_val = resolve_symbol(val_node, scope)
                
                if target.type == "Identifier":
                    if resolved_val != target:
                        if node.is_local:
                            scope.define(target.name, resolved_val)
                        else:
                            scope.update(target.name, resolved_val)
                elif target.type == "Index":
                    resolved_obj = resolve_symbol(target.obj, scope)
                    if resolved_obj and resolved_obj.type == "Table":
                        if target.key.type == "Literal" and target.key.raw_type == "STRING":
                            key_name = target.key.value
                            updated = False
                            for idx, (field_key, field_val) in enumerate(resolved_obj.fields):
                                if field_key and field_key.type == "Literal" and field_key.raw_type == "STRING" and field_key.value == key_name:
                                    resolved_obj.fields[idx] = (field_key, resolved_val)
                                    updated = True
                                    break
                            if not updated:
                                resolved_obj.fields.append((target.key, resolved_val))

    elif node.type == "Call":
        resolved_func = resolve_symbol(node.func, scope)
        func_node = resolved_func if resolved_func else node.func
        
        if func_node.type == "Identifier":
            func_name = func_node.name
            if func_name == "require" and node.args:
                arg = resolve_symbol(node.args[0], scope)
                if arg.type == "Literal" and arg.raw_type == "NUMBER":
                    findings.append({
                        "severity": "High",
                        "line": node.line,
                        "title": "Numeric Backdoor Require",
                        "description": f"Script dynamically loads external AssetId: require({arg.value})"
                    })
            elif func_name == "loadstring" and node.args:
                arg = resolve_symbol(node.args[0], scope)
                if not (arg.type == "Literal" and arg.raw_type == "STRING"):
                    findings.append({
                        "severity": "High",
                        "line": node.line,
                        "title": "Dynamic Loadstring Execution",
                        "description": "Script invokes loadstring() with a non-literal argument. This bypasses static source verification."
                    })
            elif func_name in ("hookfunction", "hookmetamethod", "getrawmetatable", "setreadonly"):
                findings.append({
                    "severity": "Medium",
                    "line": node.line,
                    "title": "Metatable or Hook Tampering",
                    "description": f"Script queries or modifies native metatables using: {func_name}()"
                })
        elif func_node.type == "Index":
            obj = resolve_symbol(func_node.obj, scope)
            key = func_node.key
            if key.type == "Literal" and key.value in ("HttpGet", "HttpPost"):
                findings.append({
                    "severity": "Medium",
                    "line": node.line,
                    "title": "External Network Connection",
                    "description": f"Script communicates with external servers using game:{key.value}()"
                })

    elif node.type == "Identifier":
        name = node.name
        if len(name) >= 6:
            charset = set(name)
            if charset.issubset({'I', 'l', '1'}) or charset.issubset({'0', 'o', 'O'}):
                findings.append({
                    "severity": "Medium",
                    "line": node.line,
                    "title": "Obfuscated Barcode Variable",
                    "description": f"Script hides definition using barcode variable naming: '{name}'"
                })

    elif node.type == "Literal" and node.raw_type == "STRING":
        val = str(node.value)
        if "discord.com/api/webhooks" in val or "discordapp.com/api/webhooks" in val:
            findings.append({
                "severity": "Medium",
                "line": node.line,
                "title": "Discord Webhook Leak",
                "description": "Script contains a Discord webhook URL, which could leak sensitive game/user telemetry."
            })

    # --- Phase 2: Structural Traversal with Block Scoping ---
    if node.type == "Table":
        for key, val in node.fields:
            if key:
                traverse_and_audit(key, findings, scope)
            traverse_and_audit(val, findings, scope)
            
    elif node.type == "If":
        traverse_and_audit(node.cond, findings, scope)
        then_scope = Scope(scope)
        traverse_and_audit(node.then_block, findings, then_scope)
        else_scope = Scope(scope)
        traverse_and_audit(node.else_block, findings, else_scope)
        
    elif node.type == "While":
        traverse_and_audit(node.cond, findings, scope)
        body_scope = Scope(scope)
        traverse_and_audit(node.body, findings, body_scope)
        
    elif node.type == "Repeat":
        body_scope = Scope(scope)
        traverse_and_audit(node.body, findings, body_scope)
        traverse_and_audit(node.cond, findings, body_scope)
        
    elif node.type == "ForNum":
        traverse_and_audit(node.start, findings, scope)
        traverse_and_audit(node.limit, findings, scope)
        if node.step:
            traverse_and_audit(node.step, findings, scope)
        body_scope = Scope(scope)
        body_scope.define(node.var_name.name, Literal(0, "NUMBER", node.var_name.line))
        traverse_and_audit(node.body, findings, body_scope)
        
    elif node.type == "ForIn":
        traverse_and_audit(node.exprs, findings, scope)
        body_scope = Scope(scope)
        for var in node.var_names:
            body_scope.define(var.name, Identifier("for_var", var.line))
        traverse_and_audit(node.body, findings, body_scope)
        
    elif node.type == "DoBlock":
        body_scope = Scope(scope)
        traverse_and_audit(node.body, findings, body_scope)
        
    elif node.type == "FunctionDef":
        if node.name:
            if node.is_local:
                scope.define(node.name.name, node)
            else:
                scope.update(node.name.name, node)
        body_scope = Scope(scope)
        for param in node.params:
            body_scope.define(param.name, Identifier("param", param.line))
        traverse_and_audit(node.body, findings, body_scope)
        
    elif node.type == "Assign":
        traverse_and_audit(node.targets, findings, scope)
        traverse_and_audit(node.values, findings, scope)
        
    elif node.type == "Call":
        traverse_and_audit(node.func, findings, scope)
        traverse_and_audit(node.args, findings, scope)
        
    elif node.type == "Index":
        traverse_and_audit(node.obj, findings, scope)
        traverse_and_audit(node.key, findings, scope)
        
    elif node.type == "BinOp":
        traverse_and_audit(node.left, findings, scope)
        traverse_and_audit(node.right, findings, scope)
        
    elif node.type == "Return":
        traverse_and_audit(node.values, findings, scope)


def main():
    source = sys.stdin.read()
    lines = source.count("\n") + (1 if source else 0)
    functions = len(re.findall(r"\bfunction\b", source))
    locals_count = len(re.findall(r"\blocal\b", source))
    requires = len(re.findall(r"\brequire\s*\(", source))

    signal_counts = {name: count_patterns(source, patterns) for name, patterns in SIGNALS.items()}
    risk = 0
    risk += min(35, signal_counts["dynamic_code"] * 10)
    risk += min(25, signal_counts["hooks"] * 8)
    risk += min(20, signal_counts["filesystem"] * 5)
    risk += min(20, signal_counts["http"] * 5)

    # 1. Lex Source
    try:
        tokens = lex(source)
    except Exception:
        tokens = []

    # 2. Parse Source
    try:
        parser = Parser(tokens)
        ast_nodes = parser.parse()
    except Exception:
        ast_nodes = []

    # 3. Analyze AST
    findings = []
    if ast_nodes:
        try:
            traverse_and_audit(ast_nodes, findings)
        except Exception:
            pass

    recommendations = []
    if findings:
        for f in findings:
            if f["severity"] == "High":
                recommendations.append(f"[Line {f['line']}] {f['title']}: {f['description']}")
    
    if signal_counts["remote_calls"]:
        recommendations.append("Open Remote Spy or Runtime Monitor and compare this script with remote call activity.")
    if requires:
        recommendations.append("Use Dependency Graph to inspect required ModuleScripts before editing behavior.")
    if signal_counts["dynamic_code"] or signal_counts["hooks"]:
        recommendations.append("Review dynamic execution and hook usage manually; automated summaries can miss intent.")
    if not recommendations:
        recommendations.append("Start with path/name search and inspect nearby scripts in Explorer.")

    output = {
        "ok": True,
        "worker": "python_deep_analysis",
        "language": "Python",
        "lines": lines,
        "bytes": len(source.encode("utf-8", "replace")),
        "functions": functions,
        "locals": locals_count,
        "requires": requires,
        "signals": signal_counts,
        "riskScore": risk,
        "topIdentifiers": top_identifiers(source),
        "recommendations": recommendations,
        "findings": findings,
    }
    print(json.dumps(output, ensure_ascii=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
