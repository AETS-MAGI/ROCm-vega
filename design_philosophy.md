# ROCm design philosophy note

> This document organizes observations from publicly available sources and local repository clones only. It does not assert the contents of private issues or internal decision-making processes.

Updated: 2026-03-17
Primary sources:

- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/ROCm/README.md`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/ROCm/docs/what-is-rocm.rst`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/TheRock/README.md`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/TheRock/cmake/therock_subproject.cmake`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/TheRock/cmake/therock_amdgpu_targets.cmake`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocm-systems/README.md`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocm-systems/projects/hip/docs/how-to/hip_runtime_api.rst`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocm-systems/projects/hip/docs/understand/programming_model.rst`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/rocBLAS/docs/what-is-rocblas.rst`
- `/home/limonene/ROCm-project/WD-Black/ROCm-repos/MIOpen/doc/src/find_and_immediate.md`

## 1. Purpose

This note fixes what can be said from public code and docs about ROCm's design tendency, with emphasis on the following questions:

- Is ROCm closer to a monolithic product or a layered stack of semi-autonomous components?
- Is hardware support treated as a binary property or as a component-specific, layer-specific property?
- Are fallback and capability checks incidental patches or recurring design patterns?
- How do recent integration projects such as `TheRock` and `rocm-systems` change the reading of the stack?

The goal is not to prove maintainer intent. The goal is to identify the strongest observable patterns in the current public tree.

## 2. Fact

### 2.1 ROCm describes itself as a stack, not a single library

- `ROCm/README.md` and `ROCm/docs/what-is-rocm.rst` describe ROCm as a software stack or collection containing drivers, development tools, APIs, libraries, runtimes, compilers, debuggers, and profilers.
- The same material places `HIP` as the main portability substrate and lists `CLR`, `HIP`, and `ROCR-Runtime` as separate runtime components.
- `ROCm/README.md` still presents the classic `repo` manifest model (`default.xml`) for multi-repository source management.

Minimum claim:

- At the public documentation level, ROCm is not presented as a single codebase or a single yes/no support surface.

### 2.2 HIP is documented as a high-level runtime over lower layers

- `rocm-systems/projects/hip/docs/how-to/hip_runtime_api.rst` states that the HIP runtime uses `CLR`.
- The same document states that `rocclr` is a virtual device interface and that the HIP runtime interacts with backends such as `ROCr` on Linux.
- `rocm-systems/projects/hip/docs/understand/programming_model.rst` describes the HIP Runtime API as a high-level interface that abstracts lower-level ROCr runtime behavior.

Minimum claim:

- ROCm publicly documents an explicit abstraction boundary between user-facing HIP runtime APIs and lower-level runtime/backend machinery.

### 2.3 TheRock moves ROCm toward a super-project integration model

- `TheRock/README.md` defines TheRock as "a lightweight open source build platform for HIP and ROCm" and explicitly calls it "a CMake super-project for HIP and ROCm source builds".
- The same README exposes top-level feature groups such as `THEROCK_ENABLE_CORE`, `THEROCK_ENABLE_MATH_LIBS`, `THEROCK_ENABLE_ML_LIBS`, and `THEROCK_ENABLE_PROFILER`.
- `TheRock/cmake/therock_subproject.cmake` defines common injected CMake variables, package advertisement, dependency mediation, and subproject activation for many components.

Minimum claim:

- TheRock is not just another package recipe. It is an integration layer that centralizes build policy, dependency wiring, and multi-component activation.

### 2.4 TheRock centralizes GPU target policy but still allows per-project exclusion

- `TheRock/cmake/therock_amdgpu_targets.cmake` defines global target metadata such as `THEROCK_AMDGPU_TARGETS`, target families, product names, and per-project exclusion lists.
- In that same file, `gfx900` is still declared as a valid target, but it carries explicit `EXCLUDE_TARGET_PROJECTS` entries for specific projects such as `hipBLASLt`, `hipSPARSELt`, `composable_kernel`, `rocWMMA`, and `rocprofiler-compute`.
- `TheRock/cmake/therock_subproject.cmake` further distinguishes `USE_DIST_AMDGPU_TARGETS`, `USE_TEST_AMDGPU_TARGETS`, and `DISABLE_AMDGPU_TARGETS`.

Minimum claim:

- TheRock treats GPU support as a structured policy space, not as a single global switch.
- At least in the public build system, a target can remain globally defined while being selectively excluded from particular components.

### 2.5 rocm-systems redefines source-of-truth for systems-side components

- `rocm-systems/README.md` states that it consolidates multiple systems projects into a single super-repo for development, CI, and integration.
- The same README contains a migration status table with explicit `Source of Truth` and `Migration Status` columns.
- `hip`, `clr`, and `rocr-runtime` are listed there as completed migrations.

Minimum claim:

- Public ROCm topology is being reorganized not only by adding code, but by relocating maintenance authority into super-repos.

### 2.6 Library-facing APIs continue to hide lower-level solver and backend complexity

- `rocBLAS/docs/what-is-rocblas.rst` describes rocBLAS as a thin C99 API using the hourglass pattern and states that Level-3 GEMMs call `Tensile` and `hipBLASLt`.
- `MIOpen/doc/src/find_and_immediate.md` shows that MIOpen user APIs expose `Find`, `GetSolution`, `CompileSolution`, and `Immediate` stages instead of exposing internal solver classes directly.
- The same MIOpen document states that immediate mode falls back to GEMM on database miss and that the fallback surface differs by backend.

Minimum claim:

- Public-facing ROCm libraries are designed to front-load stable API surfaces while deferring solver selection, fallback, and kernel realization to lower layers.

## 3. Interpretation

### 3.1 ROCm reads as a layered stack with integration pressure, not as a pure monolith

From `ROCm`, `TheRock`, and `rocm-systems` together, the strongest public reading is:

- ROCm remains componentized in implementation and ownership.
- At the same time, build, CI, packaging, and source-of-truth management are moving toward more centralized control planes.

This suggests a structure closer to:

- componentized execution and maintenance paths
- centralized integration and release pressure

than to either of the simplistic extremes:

- "everything is independent"
- "everything is one monolith"

### 3.2 Hardware support is treated as layer-specific and component-specific

TheRock's target metadata is especially important here. `gfx900` can be:

- globally recognized as a valid target
- still excluded from certain projects
- still left available to other components

This is structurally consistent with what the investigation already observes in MIOpen, rocBLAS, and shipped artifacts:

- a target may remain in build metadata
- disappear from default or preferred paths in one component
- survive through fallback or older paths in another component

### 3.3 Fallback and capability gating look like recurring design patterns

The public materials do not read as if fallback were a one-off accident.

Examples already visible from public docs and code:

- MIOpen immediate mode fallback on Find-Db miss
- rocBLAS hourglass API over Tensile / hipBLASLt
- TheRock target families plus per-project exclusion
- HIP runtime abstraction over CLR / ROCr backends

At minimum, ROCm appears to separate:

- user-facing stable entry points
- internal capability and applicability checks
- backend-specific realization paths

### 3.4 Current repo topology changes how support claims should be read

The migration to `rocm-systems` and the emergence of `TheRock` suggest that "support" can no longer be read only from a standalone library repo.

At least four different public planes now matter:

1. API and runtime behavior
2. component-local build and solver policy
3. super-project integration policy
4. migration/source-of-truth policy

This supports the investigation's broader distinction between:

- visible support
- design-level support
- build/distribution support
- practical operability

## 4. Open Question / Limitation

- `TheRock` is explicitly described as early preview. Therefore, it should not be over-read as the complete or final shape of ROCm integration policy.
- `rocm-systems` clearly defines systems-side migration status, but the same level of source-of-truth clarity is not yet established here for all math and ML libraries.
- The local `rocm-libraries` worktree appears inconsistent in this environment, so it is not used as a primary source in this note.
- Public docs and build files show structure, but they do not by themselves prove the private reasons behind individual support decisions.

## 5. Working conclusion

**Fact**:

- ROCm publicly presents itself as a layered stack.
- TheRock publicly presents itself as a super-project integration layer.
- rocm-systems publicly presents itself as a source-of-truth migration super-repo for systems components.
- GPU target policy is publicly centralized enough to support selective per-project exclusion.

**Interpretation**:

- ROCm currently reads as a layered, componentized stack under increasing integration pressure.
- Support is best read as component-specific and layer-specific, not binary.
- This is structurally consistent with the observed `gfx900` state: partial retreat, partial survival, and continued operability through selected paths.

**Open Question / Limitation**:

- How far this integration model will absorb remaining standalone math / ML repos is still not fully fixed from the public evidence used here.

## Non-claims

This document does not claim that:

- Internal decision-making processes are asserted or concluded.
- The content of private issues has been inferred or reconstructed.
- A single observed case is generalized into a universal rule.
- AMD's support policy as a whole is fully represented.
- Any specific organization is being criticized.
