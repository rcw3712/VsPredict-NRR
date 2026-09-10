# Archive scope and version mapping

## GitHub

The repository `rcw3712/VsPredict-NRR` is retained as the umbrella project-history archive. Its name records an earlier journal-target phase and does not imply that every branch or release targets that journal.

The current PED materials are isolated on branch `ped-canonical-20260910` and are identified by:

- canonical run `run_PED_corrected_20260910_071523`;
- extension manifest `ped_extension_run_PED_corrected_20260910_071523_20260910_114659`;
- figure directory `figures/ped-canonical-20260910`;
- aggregate results directory `results/ped_corrected_20260910`.

Earlier tags and the `nrr-v5-corrected-reanalysis` branch are immutable provenance snapshots. Their numerical values must not be substituted for the PED values.

## Zenodo

DOI `10.5281/zenodo.22637960` is treated as the umbrella archival record. Before publication, create a dedicated Zenodo version from the PED GitHub release and include both authoritative identifiers above in its description and files. The version-specific Zenodo DOI—not merely the umbrella DOI—should be cited in the final accepted article.

## Integrity requirements for the PED release

1. Tag the merged PED commit without rewriting earlier tags.
2. Attach the source archive, non-sensitive aggregate outputs, and run-labelled figure package.
3. Verify `FIGURE_MANIFEST_SHA256.csv`, the canonical run manifest, and the extension manifest.
4. State that row-level data and proprietary well logs are excluded.
5. Record the Git commit SHA and version-specific Zenodo DOI in the accepted-manuscript metadata.
