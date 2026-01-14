# OpenFOAM 12 migration plan (clotFoam)

## Current state (baseline)
- **Code target**: OpenFOAM Foundation **v9** (per `README.md` and tutorial file headers).
- **Build system**: `wmake` with `clotFoam/Make/{files,options}`.
- **Runtime validation**: tutorials under `tutorials/` (no scripted smoke tests).

## Complexity assessment (OpenFOAM 9 → 12 / v2412)
- **Expected complexity**: **moderate** (solver is based on `icoFoam` patterns; most `fvCFD`/PISO APIs are stable).
- **Primary risk areas**:
  - **Driver/include changes** across versions (`setRootCaseLists.H` vs `setRootCase.H`, etc.).
  - **C++ toolchain tightening**: newer compilers and OpenFOAM builds expose UB / stricter warnings.
  - **FunctionObjects / runtime libs** referenced by tutorials may differ by version (CI should not depend on optional libs).
  - **Case dictionaries**: minor keyword changes across versions; most are backward compatible, but smoke tests should be short and deterministic.

## Migration strategy
### Phase 0 — Pin a reproducible OpenFOAM 12 environment
- Use an OpenFOAM 12 container image for CI and local dev parity.
- Define a single “how to build/run” entrypoint:
  - `ci/build.sh` (compile)
  - `ci/smoke.sh` (run a short case)

### Phase 1 — Make the solver compile on OpenFOAM 12
Work items (typical OpenFOAM 9→12 issues):
- **Root-case header compatibility**: support both `setRootCaseLists.H` and `setRootCase.H`.
- **PtrList/ownership**: ensure fields stored in `PtrList<volScalarField>` are constructed via `new` (avoid relying on overloads that can change across versions).
- **Remove UB**: avoid explicit destructor calls on stack objects.
- If CI shows further build failures:
  - Adjust include names and namespaces based on the exact error messages.
  - Fix any deprecated APIs (e.g., `Time::controlDict()` access patterns, function-object libs, etc.).

### Phase 2 — Add fast smoke tests (runtime)
Goals: prove the solver starts, advances timesteps, writes at least one time directory.
- Select one tutorial as a smoke baseline (recommended: `tutorials/rectangle2D`).
- For CI:
  - Copy the case to a temp dir (don’t modify tracked tutorials at runtime).
  - Override in the copied case:
    - `endTime` very small (e.g., `1e-4`)
    - Disable `functions` (avoid optional `libutilityFunctionObjects.so` dependency)
  - Run `blockMesh` then `clotFoam`.

### Phase 3 — Full regression confidence (optional, later)
- Add a second case (e.g., `Tjunction2D`) as a longer “nightly” job.
- Compare key scalar summaries (e.g., max/min of `Theta_T`, `p`) against stored golden ranges (not bitwise).
- Add parallel run coverage (`decomposePar` + `mpirun`) once serial is stable.

## CI/CD plan (GitHub Actions)
### Minimal CI (this repo)
- **Job**: OpenFOAM v12 (Ubuntu packages) + v2412 (Docker) build + smoke run
  - v12: install via OpenFOAM.org apt repo on Ubuntu 24.04 runner
  - v2412: run via `opencfd/openfoam-dev:2412` Docker image
  - Steps:
    - compile `clotFoam`
    - run `rectangle2D` smoke
    - upload logs on failure

### Future hardening
- Add matrix for:
  - OpenFOAM versions (e.g., 11, 12)
  - Compiler variants (if needed)
- Add caching for `wmake` artifacts (optional).

## Definition of done
- `wmake` succeeds in OpenFOAM 12.
- `ci/smoke.sh` runs a case to completion in < ~2 minutes in CI.
- CI is green on push/PR for the migration branch.

