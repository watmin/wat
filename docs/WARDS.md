# WARDS — which datamancy guards are cast, and when

The builder, 2026-10-04: *"let's make sure we're utilizing the grimoire as we go... we don't need to run all spells all
the time.. but... these are our quality guards"*.

The wards are the datamancy grimoire's focused casts. Each one carries ONE class of defect. Here they are cast at the
WEIGH, after an executor scores a strike and before anything lands. A ward fits what was struck; it is never a ritual.

## How a ward is cast

- **A fresh agent per ward.** That agent fetches the ward's own signed text from the datamancy channel and reads it: one ward per agent, never a bundle, never a file the agent is told to go read. The agent reads the target cold and returns a verdict with file:line evidence.
- **Weigh the ward's verdict too.** The orchestrator weighs it against its own reading of the disk. A finding without
  a citation is discarded. A finding with one becomes a round item, or a recorded reason why it is not one.
- **Record the cast.** The ward's name, its verdict, and what was done with each finding go into that strike's WEIGH
  document.

## Which wards fit which strike

| what the strike produced | cast at the weigh | the class each one guards |
|---|---|---|
| a rung (binary plus its source) | **conferre**, **experiri**, **peragrare**, **circumspicere** | contract vs bytes; every advertised behaviour driven; what the gate never asks; the kernel and environment around it |
| a rung's README and source header | **nesciens**, **cohaerere** | can a stranger audit it cold; does the document contradict itself |
| a gate or check script (`tools/`) | **peragrare**, **vocare**, **intueri** | does the instrument discriminate; does it test what the caller sees; do its names speak |
| a mutant or exemption in a gate | **excusare** | does each exemption still earn its standing |
| watc and wat0 code, once the ladder reaches them | **cernere**, **solvere**, **purgare**, **temperare**, **struere** | phantom forms; braided concerns; dead thoughts; recomputation; values flowing honestly |
| a design or crawl document | **cohaerere**, **exigere** | one definition per term; no deferred-work prose |
| before a rung is called DONE for good | **vigilia** | every inward ward at once, then circumspicere last |

Primers are not wards. **examinare** governs every strike, **extirpare** governs every failure, **curare** runs at
every wrap-up, and **recolligere** runs after every gap.
