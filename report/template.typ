// Pandoc template for report/REPORT.pdf (scripts/build_report.py).
// Only the fonts bundled with Typst are used, so the PDF is the same on every
// machine, and the document date is fixed so a rebuild is byte-identical.
#set document(title: [$title$], author: "Alex Garcia", date: none)
#set page(
  paper: "a4",
  margin: (x: 2cm, top: 2.2cm, bottom: 2.4cm),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 8pt, fill: rgb("#5a6270"))
      Harbor Goods #h(1fr) Terraform diagnostic and repair plan
    ]
  },
  footer: context [
    #set text(size: 8pt, fill: rgb("#5a6270"))
    Fictional sample. Harbor Goods, its account and every name in this report are invented.
    #h(1fr) #counter(page).display("1 / 1", both: true)
  ],
)
#set text(font: "Libertinus Serif", size: 10.5pt, lang: "en")
#set par(justify: false, leading: 0.6em)
#show raw: set text(font: "DejaVu Sans Mono", size: 8pt)
#show raw.where(block: true): block.with(fill: rgb("#f3f5f8"), inset: 7pt, radius: 3pt, width: 100%)
#show heading: set text(fill: rgb("#1f3a5f"))
#show heading.where(level: 1): set text(size: 17pt)
#show heading.where(level: 2): it => { v(0.6em); it }
#show link: set text(fill: rgb("#1f5fa8"))
#set table(inset: 5pt, stroke: 0.4pt + rgb("#c5ccd6"))
#show table: set text(size: 9pt)
#show quote: set block(fill: rgb("#fff6e0"), inset: 8pt, width: 100%)

#let divider() = line(length: 100%, stroke: 0.4pt + rgb("#c5ccd6"))
#let horizontalRule = divider()

$body$
