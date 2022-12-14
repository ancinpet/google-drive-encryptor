# Google Drive content encryptor
Ruby CLI which uses Google Drive API to upload and encrypt Google Drive contents. If you do not remember the password of the encrypted content, it is unrecoverable and I do not carry any responsibility for how you use this application.

It utilizes zip library to encrypt any content and upload it to Google Drive - the selected content gets put into a ZIP archive with password on it.

The application can only see and work with files it made, your other files cannot be seen or accessed.

# Build and install GEM:

<pre>
Go to https://developers.google.com/drive/api/v3/quickstart/ruby
Click on Enable the Drive API.
Fill in a recognizable name and click Next.
In configure OAuth, select Desktop app and click Create.
Download the credentials.json file.
Place the credentials file into YOUR_HOME_DIRECTORY/secure-gdrive/credentials.json

Install GEM:
cd enc-drive-backup
gem build enc-drive-backup.gemspec
gem install enc-drive-backup-0.1.0.gem
secure-gdrive --help

First usage will require you to authorize the app on your Google Drive:
secure-gdrive --list
You will be asked to go to Google Drive website, click Authorize and paste the verification code back into console
</pre>

# Use CLI (after install):

Help:
<pre>
secure-gdrive
secure-gdrive -h --help
</pre>

List files:
<pre>
secure-gdrive -l --list
</pre>

Remove file:
<pre>
secure-gdrive -r --remove [ID]
</pre>

Upload file/folder:
<pre>
secure-gdrive -z --zip [source] [name] [password]
</pre>

Download zip:
<pre>
secure-gdrive -f --fetch [ID] [target] [password]
</pre>

Example usage:
<pre>
secure-gdrive -h

secure-gdrive -l
secure-gdrive --zip /tmp/myfolder mycoolfolder.zip pass123
secure-gdrive -l
secure-gdrive --fetch MY_COOL_FOLDER_ID_123456 /tmp/secondfolder pass123
secure-gdrive -r MY_COOL_FOLDER_ID_123456

secure-gdrive -l
secure-gdrive --zip README.md myreadme.zip pass321
secure-gdrive -l
secure-gdrive --fetch MY_README_ID_123456 /tmp pass321
secure-gdrive -r MY_README_ID_123456

secure-gdrive -l
secure-gdrive --zip README.md myreadme.zip pass321
secure-gdrive -l
secure-gdrive --fetch MY_README_ID_789 ../../project pass321
secure-gdrive -r MY_README_ID_789
</pre>
