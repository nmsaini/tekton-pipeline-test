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

## Using private Repositories
If your Git Repo is private, you will need to provide a authentication token to run tasks like git-clone etc. Here are the steps to setup basic-auth.

```
GITUSER=git_user
GITTOKEN=git_token_generated

oc -n $NS create secret generic git-secret \ 
--type=kubernetes.io/basic-auth \ 
--from-literal=username=$GITUSER \ 
--from-literal=password=$GITTOKEN
```

```
oc -n $NS annotate secret git-secret "tekton.dev/git-0=https://github.ibm.com"
```
Remember the host make be different in the above, since git repo maybe outside of the IBM domain. You will have to pick your own git host-server.

Now we patch the serviceaccount with the secret that we just created
```
oc -n $NS patch serviceaccount pipeline -p '{"secrets": [{"name": "git-secret"}]}'
```

## 4. trigger on commit

Create a trigger-template, with params that are received from the webhook. We do have to hardcode a fileCheck param that we are using to check if that file was in the last commit log in order to continue the pipeline build.

```
echo "
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: tekton-pl-test-trigtemplate
spec:
  params:
  - name: git-revision
  - name: git-commit-message
  - name: git-repo-url
  - name: git-repo-name
  - name: content-type
  - name: pusher-name
  - name: fileCheck
  resourcetemplates:
  - apiVersion: tekton.dev/v1beta1
    kind: PipelineRun
    metadata:
      labels:
        tekton.dev/pipeline: build-if-filecommited
      name: build-if-filecommited-$(uid)
    spec:
      params:
      - name: APP_NAME
        value: $(tt.params.git-repo-name)
      - name: APP_GIT_URL
        value: $(tt.params.git-repo-url)
      - name: APP_GIT_REVISION
        value: $(tt.params.git-revision)
      - name: fileCheck
        value: test2.ace
      pipelineRef:
        name: build-if-filecommited
      serviceAccountName: pipeline
      workspaces:
      - name: git-source
        persistentVolumeClaim:
          claimName: pipelines-storage-001
" | oc -n $NS create -f -
```

create an event-listener, using a default cluster-trigger-binding (defined for us by RedHat)

```
echo "
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-listener
spec:
  namespaceSelector: {}
  resources: {}
  serviceAccountName: pipeline
  triggers:
    - bindings:
        - kind: ClusterTriggerBinding
          ref: github-push
      template:
        ref: tekton-pl-test-trigtemplate
" | oc -n $NS create -f -
```

This eventlistener, once created will also create a service named `el-${EventListener Name}`, in our case it is `el-github-listener`.
Lets expose this as a route, such that github can use an webhook to call our pipeline build.

```
oc expose svc el-github-listener
```

Now the plumbing is all set. For Github to call our EventListener via a webhook.
From the project settings in Github add a webhook with the route that was just exposed.

