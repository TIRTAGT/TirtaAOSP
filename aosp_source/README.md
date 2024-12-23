# AOSP
This folder is a container for any extracted files from the [official android source](https://cs.android.com/android/platform/superproject/main) to ease up building, such as getting the ``development/tools/make_key`` script to create release keys.

I do not claim that anything in this folder are mine, they are all from the official android source synced manually by me, I may apply some patches here and there, all patches are in the form of file with ".patch" suffix.

To apply those patches, just patch using git on this directory:
```bash
git apply ./*.patch
```

## LICENSE
The files in this folder are licensed under the Apache v2.0 License<br>
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

For convenience, I had wget-ed the txt variant of the Apache v2.0 license file and put it in this folder too.