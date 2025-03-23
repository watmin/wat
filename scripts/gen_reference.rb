# frozen_string_literal: true

require 'kramdown'
require 'kramdown-parser-gfm'

markdown = File.read(File.join(__dir__, '..', 'reference.md'))
html = Kramdown::Document.new(markdown, input: 'GFM').to_html

styled_html = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.2.0/github-markdown.min.css">
    <style>
      body { margin: 0; padding: 0; background-color: #1a1a1a; }
      .markdown-body {
        box-sizing: border-box;
        min-width: 200px;
        max-width: 980px;
        margin-left: 300px;
        margin-right: 300px;
        padding: 45px;
        background-color: #1a1a1a;
        color: #ffffff;
      }
      .markdown-body pre, .markdown-body code { background: #333333; color: #ffffff; }
      .markdown-body a { color: #58a6ff; }
    </style>
  </head>
  <body>
    <article class="markdown-body">
      #{html}
    </article>
  </body>
  </html>
HTML

puts styled_html
