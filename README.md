# tekton-pipeline-test

**POC Goal** - Test Pipeline gets triggered from a Webhook when there are changes commited to the repo. However, we want to only proceed with the build/deploy (which is currently not shown in the pipeline) if and only if a specific file was commited.

# steps:
## 1. create the task & pipeline definition
```
NS=cp4i
oc -n $NS create -f tekton/tk-git-checkifcommited.yaml
oc -n $NS create -f tekton/pl-build-if-filecommited.yaml
```

## 2. create PVC storage
```
oc -n $NS create -f tekton/pvc-pipeline-storage.yaml
```

## 3. start the pipeline
```
tkn pipeline start build-if-filecommited \
    --workspace name=git-source,claimName=pipelines-storage-001 \
    --param fileCheck=test2.ace --showlog
```

## Notes

If you are working in your own repo, you will need a copy of the script/check-file-commit.sh in your own repo. This script execution will either be successful (when finding the specific file in the commit log) or failing (when file is not in the last commit log). This has an effect of either passing/continuing the pipeline or failing and thus stopping/erroring out) the pipeline. The full pipeline is not shown here, this is simply a concept.

The fileCheck parameter is the specific file that we are looking for in the last commit. All the other files in the repo are just there for testing various tests and are not needed. 

In order to get a successful build of the pipeline. Simply update the test2.ace file (since that is the file we are looking for) and commit to the repo.

```
echo "update: $(date +%Y-%m-%d)" >> deployment/test2.ace
git add --all
git commit -m "updated file of interest"
git push origin
```

Then re-run the last pipeline to validate. Use the same last config/params in the last run.
```
tkn pipeline start build-if-filecommited --last --showlog
```
