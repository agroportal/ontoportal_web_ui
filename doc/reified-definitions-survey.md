# Reified definitions on AgroPortal — survey

Survey date: 2026-08-06
API: `https://data.agroportal.eu` · SPARQL: `https://sparql.agroportal.eu/sparql`

Some vocabularies do not attach a definition to a concept as a literal. They point at a
separate RDF node that carries the text plus its provenance:

```
skos:Concept  --skos:definition-->  <node>  --rdf:value-->  "Coastal areas are commonly…"@en
                                            --vocbench:hasSource--> "FAO, 1998, http://…"
                                            --dcterms:created-->    "2020-09-15T13:23:07"
```

The web UI renders whatever `definition` holds. When it holds a node URI, the user sees a bare
URL where a sentence should be. This survey establishes exactly which ontologies are affected
and which of them the REST API can resolve.

## Result

**12 ontologies use reified definitions.** Whether the web UI can resolve the node is predicted
perfectly by one thing: whether the node carries `rdf:type owl:NamedIndividual`.

| Ontology | | Node `rdf:type` | `instances/<uri>` | Resolvable |
|---|---|---|---|---|
| GACS | | `Definition`, `NamedIndividual` | 200 | yes |
| INRAETHES | | `Resource`, `NamedIndividual` | 200 | yes |
| NALT | | `Definition`, `NamedIndividual` | 200 | yes |
| NALT-AWIC | view of NALT | `Definition`, `NamedIndividual` | 200 | yes |
| NALT-CORE | view of NALT | `Definition`, `NamedIndividual` | 200 | yes |
| NALT-TAXON | view of NALT | `Definition`, `NamedIndividual` | 200 | yes |
| AGROVOC | | *untyped* | 500 | **no** |
| AGROVOC-PT-BR | view of AGROVOC | *untyped* | 500 | **no** |
| ASFA | | *untyped* | 500 | **no** |
| LANDVOC | | *untyped* | 500 | **no** |
| ANAEETHES | | *untyped* | 500 | **no** |
| FPOSOFT | | *untyped* | 500 | **no** |

An even 6 / 6, with no exceptions across the full catalogue.

`LinkedData::Models::Instance` requires `owl:NamedIndividual`, so an untyped node is invisible to
every typed REST endpoint the API exposes — `classes/`, `instances/`, `skos_xl_labels/` all miss
it. This is structural, not a bug waiting to be fixed. (The 500 *is* a bug: the endpoint should
return 404 as it does without `include=all`. Fixing it would turn a broken response into an
honest empty one, not into a working lookup.)

### Scale of the unresolvable half

| Ontology | Reified definition nodes |
|---|---|
| AGROVOC | 24,639 |
| AGROVOC-PT-BR | 3,728 |
| ASFA | 3,467 |
| LANDVOC | 621 |
| ANAEETHES | 496 |
| FPOSOFT | not countable — no SPARQL graph |
| **Total (excl. FPOSOFT)** | **32,951** |

## Predicates

`rdf:value` carries the text in **all 12**. `ResourceLookupService::VALUE_PREDICATES` leads with it,
so detection needs nothing added.

Provenance varies and would need three predicates if ever surfaced:

| Predicate | Used by |
|---|---|
| `dcterms:source` | GACS, INRAETHES, NALT + views, AGROVOC (minority) |
| `vocbench:hasSource` | AGROVOC, AGROVOC-PT-BR, ASFA, LANDVOC, FPOSOFT |
| `prov:wasQuotedFrom` | ANAEETHES only |

Dates: `dcterms:created` is common, `dcterms:modified` occasional.

### Language

The text is tagged, the node is not — which is why a language-filtered class keeps every node it
points at while dropping the literals it does not want. Both sources can tell the two apart, so the
node's language never has to be guessed:

- REST honours `lang=` on `instances/<uri>`: `rdf:value` comes back null for a node whose text is in
  another language, while its untagged provenance stays.
- SPARQL returns `xml:lang` on each literal binding.

Untagged literals belong to every language and are kept whatever is asked for.

## Method

1. **Catalogue.** `GET /ontologies?include_views=true` → **312 ontologies**. The default listing
   returns 261; it hides **51 views**. Four of the twelve below are views, so omitting
   `include_views` loses a third of the affected set.
2. **Filter.** Reified definitions are a SKOS pattern. By `hasOntologyLanguage`: OWL 217,
   SKOS 29, OBO 14, UMLS 1 (excluding views); 51 SKOS including them. No OWL, OBO or UMLS
   ontology in the catalogue uses the pattern.
3. **Scan.** Every SKOS vocabulary, paging `classes?include=definition` looking for a definition
   value that is an IRI. Five needed scanning to the last class to rule out:
   AFO 31,781 · FOODEX2 27,894 · THESAGRO 10,067 · GEMET 5,573 · AGFOOD 3,117 — all clean.
4. **Classify.** For each candidate, resolve the URI two ways — REST `instances/<uri>` and a
   SPARQL `SELECT ?p ?o` — and count it as reified only if it carries `rdf:value` or
   `skosxl:literalForm`.

### Why both sources were needed

Neither alone is sufficient, which is worth knowing before repeating this:

- **SPARQL is exhaustive only within its store.** FPOSOFT has no graph there
  (`ASK` on its submissions 1–3 is false), so a SPARQL-only sweep misses it entirely.
- **REST page-1 sampling produces false negatives.** NALT-TAXON's first IRI definition is on
  page 3; CROPUSAGE's on page 3.

## False positives worth remembering

Values that are IRIs but not reified nodes — a URL typed into a definition field, or a definition
pointing at a controlled-vocabulary term:

| Ontology | Value | Why not reified |
|---|---|---|
| CROPUSAGE | `http://ontology.inrae.fr/frenchcropusage/res` | no triples anywhere |
| SCO, SUMSO | `…/AnnotationVocabulary/Released` | a term, carries no `rdf:value` |
| SCO-U, SPFOOD, SPO-FDM | `…food.owl#SideCourse`, `gufo#isComponentOf` | class IRIs |
| AQFO | `obo/TO_0000607` | class IRI |
| SAREF4AGRI | `https://saref.etsi.org/core/` | namespace URL |
| OESO-SIXTINE-V | `https://www.fao.org/wiews/glossary/fr/ - 2026-05-12` | citation string |
| VBO | `http://www.wkc.org.au/` | plain URL |

Nothing resolves them, and nothing should: they are the values the Definitions row keeps showing as
the identifiers they are, since there is no node to open and no text to show instead.

## Implications for the web UI

1. **`DefinitionsComponent` should never render an IRI as prose.** This applies to all 12
   ontologies above *and* to the false positives — 19 in total — regardless of what else is built.
2. **The REST lookup covers half the cases.** `ResourceLinksHelper#reified_resource_chip` works
   for the six typed ontologies and is a no-op for the six untyped ones (it fails safe, falling
   back to the previous external link).
3. **A SPARQL fallback is the only way to reach the untyped six**, since no REST endpoint can
   see an untyped node. Shape: REST first, SPARQL only when it returns nothing, so the working
   six cost nothing extra.
   - The app already has `$SPARQL_ENDPOINT_URL` and `SparqlHelper`.
   - `.env` currently points at `sparql.stage.agroportal.eu`, not the endpoint surveyed here.
   - Coverage still is not total: FPOSOFT has no SPARQL graph, and resolved only because
     AGROVOC shares the URI and *is* in the store. SPARQL widens coverage without guaranteeing it.
   - Queries must be bound to a single subject URI. An unscoped
     `SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } }` is rejected by the endpoint with a 500.
4. **A resolved node belongs in the prose, not beside it.** The API now extracts the text of a
   reified definition into the class as a literal too, so a language-filtered class can hold the
   same definition twice — once as a sentence, once as the address of the node it was read from.
   `DefinitionsComponent` resolves each node and folds it back in: the text is shown once, carrying
   a link to the node's raw data, and a node holding nothing in this language is left to the "all
   languages" view. Submissions parsed before the extraction hold nodes and no literals at all —
   AGROVOC among them — so the node's own text is what the row shows for those.

## Reproducing

Graphs using the pattern (exhaustive within the SPARQL store — returns 11, missing FPOSOFT):

```sparql
SELECT DISTINCT ?g WHERE {
  GRAPH ?g { ?c <http://www.w3.org/2004/02/skos/core#definition> ?d . FILTER(isIRI(?d)) }
}
```

Everything one node holds — works regardless of typing, which is the point:

```sparql
SELECT DISTINCT ?p ?o WHERE { <http://aims.fao.org/aos/agrovoc/xDef_46a719b8> ?p ?o }
```

Predicate profile for one ontology's definition nodes:

```sparql
SELECT ?p (COUNT(*) AS ?n) WHERE {
  { SELECT ?d WHERE {
      GRAPH <http://data.bioontology.org/ontologies/AGROVOC/submissions/61> {
        ?c <http://www.w3.org/2004/02/skos/core#definition> ?d . FILTER(isIRI(?d)) } }
    LIMIT 100 }
  GRAPH <http://data.bioontology.org/ontologies/AGROVOC/submissions/61> { ?d ?p ?o }
} GROUP BY ?p ORDER BY DESC(?n)
```

## Worked example

`FPOSOFT` / `http://aims.fao.org/aos/agrovoc/c_9000021` ("coastal areas") has two definitions,
both unresolvable through REST. Retrieved by SPARQL:

**`xDef_46a719b8`**

- `rdf:value` @en — "Coastal areas are commonly defined as the interface or transition areas
  between land and sea, including large inland lakes. Coastal areas are diverse in function and
  form, dynamic and do not lend themselves well to definition by strict spatial boundaries.
  Unlike watersheds, there are no exact natural boundaries that unambiguously delineate coastal
  areas."
- `vocbench:hasSource` — "Integrated coastal area management and agriculture, forestry and
  fisheries / FAO, 1998 / http://www.fao.org/3/w8440e/W8440e02.htm"
- `dcterms:created` — 2020-09-15

**`xDef_de8c4696`**

- `rdf:value` @pt — "Litoral é a região junto ou próximo da costa marítima, onde se faz sentir a
  influência directa ou indirecta da acção do mar."
- `dcterms:created` — 2016-07-05

The page currently shows the two URIs as plain black paragraphs.
