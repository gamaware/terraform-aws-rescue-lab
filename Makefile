# One entry point for every offline check. CI runs `make verify` too, so a green
# local run means a green pipeline. Nothing here calls AWS.

TERRAFORM ?= terraform
TFLINT ?= tflint
CHECKOV ?= uvx --python 3.13 --from checkov==3.3.19 checkov
MOTO ?= moto[server,proxy]==5.2.3
ACTIONLINT_PY ?= actionlint-py==1.7.12.25

TF_ROOTS := before/dev before/prod after/bootstrap after/envs/dev after/envs/prod \
	after/modules/app-storage after/modules/app-storage/examples/basic
SHELL_SCRIPTS := $(wildcard scripts/*.sh scripts/tests/*.sh migration/demo/*.sh .claude/hooks/*.sh)

export TF_IN_AUTOMATION := 1
export TF_INPUT := 0
export CHECKOV TFLINT

.PHONY: verify tools fmt validate test findings plan-gate shell workflows report-check \
	report evidence demo test-live clean help

## verify: every offline check (tools, fmt, validate, test, findings, plan-gate, shell, workflows, report-check)
verify: tools fmt validate test findings plan-gate shell workflows report-check
	@echo "verify: all checks passed"

## tools: fail early if a scanner version differs from the one the evidence was recorded with
tools:
	@$(CHECKOV) --version | tail -n 1 | grep -qx '3.3.19' || { echo "checkov 3.3.19 required"; exit 1; }
	@$(TFLINT) --version | grep -q 'TFLint version 0.61.0' || { echo "tflint 0.61.0 required"; exit 1; }
	@$(TERRAFORM) version -json | jq -e '.terraform_version | split(".") | (.[0] == "1" and (.[1] | tonumber) >= 11)' \
		>/dev/null || { echo "terraform 1.11 or later required"; exit 1; }
	@echo "pass  tool versions"

## fmt: terraform fmt check across the repository
fmt:
	$(TERRAFORM) fmt -check -recursive -diff

## validate: init without a backend and validate every root, before/ included
validate:
	@for dir in $(TF_ROOTS); do \
		$(TERRAFORM) -chdir="$$dir" init -backend=false >/dev/null || exit 1; \
		out="$$($(TERRAFORM) -chdir="$$dir" validate -no-color 2>&1)" || { echo "$$dir: $$out"; exit 1; }; \
		echo "$$dir: $$out"; \
	done

## test: terraform test with mock_provider for the app-storage module
test:
	$(TERRAFORM) -chdir=after/modules/app-storage init -backend=false >/dev/null
	$(TERRAFORM) -chdir=after/modules/app-storage test

## findings: before/ fails exactly the recorded checks; after/ fails none
findings:
	scripts/check-findings.sh

## plan-gate: the plan JSON gate against its fixtures
plan-gate:
	scripts/tests/test-check-plan.sh

## shell: shellcheck and shellharden on every script
shell:
	shellcheck --severity=warning $(SHELL_SCRIPTS)
	shellharden --check $(SHELL_SCRIPTS)

## workflows: actionlint on the active workflows and on the examples for the client's CI
workflows:
	uvx --from '$(ACTIONLINT_PY)' actionlint .github/workflows/*.yml examples/workflows/*.yml

## report-check: report/REPORT.pdf was built from the current report/REPORT.md (hashes in report/REPORT.sha256)
report-check:
	@shasum -a 256 --check --status report/REPORT.sha256 \
		|| { echo "FAIL  report/REPORT.pdf is out of date: run make report and commit it"; exit 1; }
	@echo "pass  report/REPORT.pdf matches report/REPORT.md"

## report: rebuild report/REPORT.pdf with the pinned pandoc/latex image (needs Docker)
report:
	uv run --no-project --python 3.13 python scripts/build_report.py

## evidence: rewrite report/evidence/ from the scanners (review the diff before committing)
evidence:
	scripts/check-findings.sh --update

## demo: replay the prod state migration against moto (starts and stops the emulator)
demo:
	scripts/run-demo.sh

## test-live: apply, assert and destroy the module in a real account (maintainer only, profile dev)
test-live:
	scripts/test-live.sh

## clean: remove local Terraform working directories
clean:
	find . -type d -name .terraform -prune -exec rm -rf {} +

help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
