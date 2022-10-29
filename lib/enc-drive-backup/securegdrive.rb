#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'thor'
require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'pathname'
require 'tmpdir'
require 'zip'
require 'archive/zip'
require_relative('zipper')

Drive = Google::Apis::DriveV3

# Google OAuth
OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
# App name
APPLICATION_NAME = 'Ruby Secure Google Drive Storage'
# Where Google API key is stored
CREDENTIALS_PATH = File.expand_path('~') + '/secure-gdrive/credentials.json'
# Where Google Login token is stored
TOKEN_PATH = File.expand_path('~') + '/secure-gdrive/token.yaml'
# Application access scope (currently only files created by the app itself)
SCOPE = Drive::AUTH_DRIVE_FILE

# @author Petr Ancinec
class SecureGDrive < Thor # rubocop:disable Metrics/ClassLength
  map %w[--list -l] => :__list_files
  map %w[--remove -r] => :__remove_file
  map %w[--zip -z] => :__zip_upload
  map %w[--fetch -f] => :__google_download

  desc '--list -l', 'Lists all available rzips on your Google Drive'
  # Connects to Google Drive using OAuth and lists possible files.
  def __list_files
    drive_service = service
    response = drive_service.list_files(
      page_size: 1000,
      fields: 'nextPageToken, files(id, name)'
    )
    puts 'Accessible files:'
    puts 'You haven\'t made any files yet' if response.files.empty?
    response.files.each do |file|
      puts("#{file.name} (#{file.id})")
    end
  end

  desc '--remove -r [ID]', 'Removes an rzip file identified by Google Drive [ID] from Google Drive'
  # Connects to Google Drive using OAuth and removes a file by ID.
  #
  # == Parameters:
  # argument::
  #   String (Google Drive File ID) to be removed from Google Drive
  #
  # == Returns:
  # Removed file name and ID to stdout
  #
  def __remove_file(id) # rubocop:disable Metrics/MethodLength
    drive_service = service
    response = drive_service.list_files(
      page_size: 1000,
      fields: 'nextPageToken, files(id, name)'
    )
    response.files.each do |file|
      if file.id == id # rubocop:disable Style/Next
        puts("Removing file #{file.name} (#{file.id})")
        drive_service.delete_file(id)
        puts("File #{file.name} (#{file.id}) removed")
        return ''
      end
    end
    puts("File with ID #{id} was not found, application can only access files it created.")
  end

  desc '--zip -z [source] [name] [password]', 'Creates an rzip from given file/folder [source] and uploads it' \
       ' encrypted with [password] to Google Drive as [name]'
  # Creates password encrypted ZIP and uploads it to Google Drive.
  #
  # == Parameters:
  # argument::
  #   Source file or folder to be zipped
  # argument::
  #   File name on Google Drive
  # argument::
  #   Password to encrypt the ZIP with
  #
  # == Returns:
  # Operation progress to stdout
  #
  def __zip_upload(source, drive_name, password) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    if !File.directory?(source) && !File.file?(source)
      puts("#{source} is not a file nor a directory.")
      exit(1)
    end

    drive_service = service
    location = create_workfolder
    zip_folder(source, location, password) if File.directory?(source)
    zip_file(source, location, password) if File.file?(source)
    zip_name_protected = Pathname.new(source).basename.to_s + '_protected.zip'
    password_zip = location + zip_name_protected
    puts("Starting upload of '#{password_zip}' -> 'GDrive:#{drive_name}'")
    file_metadata = {
      name: drive_name
    }
    file = drive_service.create_file(file_metadata,
                                     fields: 'id',
                                     upload_source: password_zip,
                                     content_type: 'application/zip')
    puts("Uploaded '#{password_zip}' -> 'GDrive:#{drive_name}', GDrive id: #{file.id}")
    clean_workfolder(location)
  end

  desc '--fetch -f [ID] [target] [password]', 'Retrieves an rzip from Google Drive [ID] and decrypts it with' \
       ' [password] into given folder [target]'
  # Downloads a ZIP from Google Drive by ID and extracts it to target directory decrypting it with password 
  #
  # == Parameters:
  # argument::
  #   ID of ZIP to extract from Google Drive
  # argument::
  #   Folder where to extract the ZIP to
  # argument::
  #   Password to decrypt the ZIP with
  #
  # == Returns:
  # Operation progress to stdout
  #
  def __google_download(id, destination, password) # rubocop:disable Metrics/MethodLength
    drive_service = service
    location = create_workfolder
    response = drive_service.list_files(
      page_size: 1000,
      fields: 'nextPageToken, files(id, name)'
    )
    response.files.each do |file|
      if file.id == id # rubocop:disable Style/Next
        process_file(drive_service, file, location, destination, password)
        clean_workfolder(location)
        return ''
      end
    end
    clean_workfolder(location)
    puts("File with ID #{id} was not found, application can only access files it created.")
  end

  no_commands do # rubocop:disable Metrics/BlockLength
    # Google OAuth
    #
    # == Parameters:
    #
    # == Returns:
    # OAuth credentials
    #
    def authorize # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      begin
        client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
      rescue StandardError
        puts("File #{CREDENTIALS_PATH} does not exist.")
        puts('Please create it according to the README document.')
        exit(1)
      end
      token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
      authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
      user_id = 'default'
      credentials = authorizer.get_credentials user_id
      if credentials.nil?
        url = authorizer.get_authorization_url base_url: OOB_URI
        puts('Open the following URL in the browser and enter the ' \
             'resulting code after authorization. The program can ' \
             'only access files made by it, your other files will not be seen.')
        puts('')
        puts(url)
        puts('')
        code = ask('Authorization code: ')
        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id, code: code, base_url: OOB_URI
        )
      end
      credentials
    end

    # Google API wrapper
    #
    # == Parameters:
    #
    # == Returns:
    # Google service object
    #
    def service
      drive_service = Drive::DriveService.new
      drive_service.client_options.application_name = APPLICATION_NAME
      drive_service.authorization = authorize
      drive_service
    end

    # Downloads a file into temporary directory
    def process_file(drive_service, file, location, destination, password)
      puts("Downloading file #{file.name} (#{file.id})")
      local_file_name = location + file.name
      local_folder_name = local_file_name + '_extracted/'
      drive_service.get_file(file.id, download_dest: local_file_name)
      puts("File #{file.name} (#{file.id}) downloaded 'GDrive:#{file.name}' -> '#{local_file_name}'")
      puts("Decrypting zip '#{local_file_name}' -> '#{destination}'")
      extract_file(local_file_name, local_folder_name, location, destination, password)
    end

    # Checks if file can by decrypted with given password
    def extract_file(local_file_name, local_folder_name, location, destination, password)
      begin
        Archive::Zip.extract(local_file_name, local_folder_name, password: password)
      rescue StandardError
        puts('Invalid password, terminating operation')
        clean_workfolder(location)
        exit(1)
      end
      finalize_file(local_file_name, local_folder_name, destination, password)
    end

    # Extracts file from temporary directory to final destination
    def finalize_file(local_file_name, local_folder_name, destination, password)
      Dir["#{local_folder_name}*_unprotected.zip"].each do |file_name|
        Archive::Zip.extract(file_name, destination)
        return ''
      end
      Archive::Zip.extract(local_file_name, destination, password: password)
    end

    # Creates a password protected ZIP from folder.
    # Folder is zipped twice to prevent inspection of inner structure,
    # since ZIP only encrypts file content and not metadata
    def zip_folder(source, location, password) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      zip_name_unprotected = Pathname.new(source).basename.to_s + '_unprotected.zip'
      zip_name_protected = Pathname.new(source).basename.to_s + '_protected.zip'
      non_password_zip = location + zip_name_unprotected
      password_zip = location + zip_name_protected
      puts("Zipping folder '#{source}' -> '#{non_password_zip}'")
      zf = ZipFileGenerator.new(source, non_password_zip)
      zf.write
      puts("Encrypting zip '#{non_password_zip}' -> '#{password_zip}'")
      Zip::OutputStream.open(password_zip, Zip::TraditionalEncrypter.new(password)) do |out|
        out.put_next_entry(zip_name_unprotected)
        out.write File.open(non_password_zip).read
      end
    end

    # Creates a password protected ZIP from file
    def zip_file(source, location, password)
      file_name = Pathname.new(source).basename.to_s
      zip_name_protected = Pathname.new(source).basename.to_s + '_protected.zip'
      password_zip = location + zip_name_protected

      Zip::OutputStream.open(password_zip, Zip::TraditionalEncrypter.new(password)) do |out|
        out.put_next_entry(file_name)
        out.write File.open(source).read
      end
    end

    # Creates a temporary work folder where files will be processed
    def create_workfolder
      temp_folder = Dir.tmpdir + '/secure-gdrive-temp/'
      guard = rand 1_000_000
      location = temp_folder + "#{guard}/"
      puts("Creating workfolder '#{location}'")
      FileUtils.mkdir_p(location)
      location
    end

    # Cleans up the temporary work folder
    def clean_workfolder(location)
      puts("Cleaning up workfolder '#{location}'")
      FileUtils.remove_dir(location)
    end
  end

  def self.exit_on_failure?
    true
  end
end
