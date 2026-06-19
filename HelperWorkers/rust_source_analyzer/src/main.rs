use std::collections::{HashMap, HashSet};
use std::io::{self, Read};

fn escape_json(value: &str) -> String {
    let mut out = String::with_capacity(value.len() + 8);
    for ch in value.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c.is_control() => out.push(' '),
            c => out.push(c),
        }
    }
    out
}

fn count_token(source: &str, token: &str) -> usize {
    source.match_indices(token).count()
}

fn top_identifiers(source: &str, limit: usize) -> Vec<(String, usize)> {
    let reserved: HashSet<&str> = [
        "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if",
        "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until",
        "while", "self", "game", "workspace", "script",
    ]
    .into_iter()
    .collect();

    let mut counts: HashMap<String, usize> = HashMap::new();
    let mut word = String::new();
    for ch in source.chars() {
        if ch.is_ascii_alphanumeric() || ch == '_' {
            word.push(ch);
        } else if !word.is_empty() {
            if word.len() >= 3 && !reserved.contains(word.as_str()) {
                *counts.entry(word.clone()).or_insert(0) += 1;
            }
            word.clear();
        }
    }
    if !word.is_empty() && word.len() >= 3 && !reserved.contains(word.as_str()) {
        *counts.entry(word).or_insert(0) += 1;
    }

    let mut rows: Vec<(String, usize)> = counts.into_iter().collect();
    rows.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    rows.truncate(limit);
    rows
}

fn main() {
    let mut source = String::new();
    io::stdin().read_to_string(&mut source).unwrap();

    let lines = if source.is_empty() { 0 } else { source.lines().count() };
    let functions = count_token(&source, "function");
    let locals = count_token(&source, "local ");
    let requires = count_token(&source, "require");
    let remote_calls = count_token(&source, "FireServer") + count_token(&source, "InvokeServer");
    let hooks = count_token(&source, "hookfunction") + count_token(&source, "hookmetamethod");
    let dynamic = count_token(&source, "loadstring") + count_token(&source, "getfenv");
    let http = count_token(&source, "HttpGet") + count_token(&source, "HttpPost");

    let risk_score = (hooks * 10 + dynamic * 8 + http * 5).min(100);
    let identifiers = top_identifiers(&source, 16);
    let identifier_json = identifiers
        .iter()
        .map(|(name, count)| format!("{{\"name\":\"{}\",\"count\":{}}}", escape_json(name), count))
        .collect::<Vec<_>>()
        .join(",");

    println!(
        "{{\"ok\":true,\"worker\":\"rust_source_analyzer\",\"language\":\"Rust\",\"lines\":{},\"bytes\":{},\"functions\":{},\"locals\":{},\"requires\":{},\"signals\":{{\"remote_calls\":{},\"hooks\":{},\"dynamic_code\":{},\"http\":{}}},\"riskScore\":{},\"topIdentifiers\":[{}]}}",
        lines,
        source.len(),
        functions,
        locals,
        requires,
        remote_calls,
        hooks,
        dynamic,
        http,
        risk_score,
        identifier_json
    );
}
