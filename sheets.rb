require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"

'''
This script is intended to record two CineFiles user entered data points, 
the user IP address, and a timestamp.

user_category: user selects from a dropdown: ["student","professor","animal lover"]
user_affiliation: free text: "Miskatonic University"
ip_address: collected by RoR [?]
timestamp: Time.now

These data are posted to a Google Sheet owned by PFA Library, 
using our API credentials
Credentials are stored on the filesystem (is this legit?)

`main` should be called, which first inserts a blank row at index 0
then it updates the new row with the user data

'''

# https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit
SECRETS_PATH = 'secrets/secrets.json'.freeze
CREDENTIALS_PATH = "secrets/credentials.json".freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = "secrets/token.yaml".freeze

SPREADSHEET_ID = JSON.parse(File.read(SECRETS_PATH))['SPREADSHEET_ID']
# puts SPREADSHEET_ID

OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "Google Sheets API Stats Gatherer".freeze
SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS

## THE authorize METHOD IS FROM THE GOOGLE DEMO SCRIPT
## IT SHOULD PROBABLY BE REPLACED WITH BETTER ERROR
## HANDLING IF IT'S TO BE RUN ON A SERVER

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
  token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
  authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
  user_id = "default"
  credentials = authorizer.get_credentials user_id
  if credentials.nil?
    url = authorizer.get_authorization_url base_url: OOB_URI
    puts "Open the following URL in the browser and enter the " \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

# Initialize the SHEETS API as "SERVICE"
SERVICE = Google::Apis::SheetsV4::SheetsService.new
SERVICE.client_options.application_name = APPLICATION_NAME
SERVICE.authorization = authorize

def insert_row()
  '''
  This inserts a row at index 0
  '''
  # This is the range of rows/columns to be modified/updated
  dimension_range = Google::Apis::SheetsV4::DimensionRange.new
  dimension_range.sheet_id = 0
  dimension_range.dimension = "ROWS"
  dimension_range.start_index = 0
  dimension_range.end_index = 1

  # This is the request object for inserting rows/columns
  insert_dimension_request = Google::Apis::SheetsV4::InsertDimensionRequest.new
  insert_dimension_request.range = dimension_range
  insert_dimension_request.inherit_from_before = false

  # This is the basic Request object, that can take one or more (??) request Objects
  insert_request = Google::Apis::SheetsV4::Request.new
  insert_request.insert_dimension = insert_dimension_request

  # This is the actual API request that is executed in batch_update_spreadsheet()
  batch_update_spreadsheet = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
  batch_update_spreadsheet.requests = [insert_request]
  batch_update_spreadsheet.include_spreadsheet_in_response = true
  batch_update_spreadsheet.response_include_grid_data = false
  batch_update_spreadsheet.response_ranges = ["Sheet1!A1:C1"]

  insert_response = SERVICE.batch_update_spreadsheet(SPREADSHEET_ID, batch_update_spreadsheet)
  # puts insert_response.to_json
end

def log_user_values(user_category:,user_affiliation:,ip_address:)
  '''
  This inserts the user supplied values to the new empty row
  '''
  # This is the range to update, plus the values to insert
  value_request_body = Google::Apis::SheetsV4::ValueRange.new
  value_request_body.major_dimension="ROWS"
  value_request_body.values=[[user_category,user_affiliation,ip_address,Time.now]]
  value_request_body.range = "Sheet1!A1:D1"

  # You also need to declare the range here too for some stupid reason
  range = "Sheet1!A1:D1"

  value_response = SERVICE.update_spreadsheet_value(SPREADSHEET_ID, range, value_request_body, value_input_option: "USER_ENTERED")
  puts value_response.to_json
end

########### Actually make the API Calls ############

def main(user_category:, user_affiliation:,ip_address:)
  insert_row
  log_user_values(user_category: user_category, user_affiliation: user_affiliation, ip_address:ip_address)
end
