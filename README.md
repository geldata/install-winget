# setup-winget

Action to install [winget-cli](https://github.com/microsoft/winget-cli) on
Windows runners.

## Usage

```yml
    - name: Install winget
      uses: geldata/setup-winget@v1
```

### Example

`.github/workflows/test-job.yml`
```yml
jobs:
  test-job:
    name: Test Job
    runs-on: windows-latest
    steps:
    - name: Install winget
      uses: geldata/setup-winget@v1
      with:
        winget-version: latest  # or any semver constraint, e.g. 1.11.x

    - name: Install wingetcreate
      run: winget install wingetcreate --disable-interactivity --accept-source-agreements
```

### Inputs

#### `winget-version` (Optional)

Version range or exact version of a Python version to use, using
SemVer's version range syntax or 'latest' for the latest stable
version of winget. To see what versions are available,
look at https://api.github.com/repos/microsoft/winget-cli/releases.
Defaults to `>=1.9.25200` (which is the oldest supported version
  that is installable by this action).

### Outputs

#### `winget-version`

The output of `winget --version` for the installed version.

```yml
    - uses: geldata/setup-winget@v1
      id: stepid

    - run: echo '${{ steps.stepid.outputs.winget-version }}' # i.e. v1.6.1573-preview
```
