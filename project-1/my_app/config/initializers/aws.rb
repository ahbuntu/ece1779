# load credentials from disk
creds = YAML.load(File.read('config/aws.yml'))

# Aws::EC2::Client.new(
#   access_key_id: creds['access_key_id'],
#   secret_access_key: creds['secret_access_key'],
#   :logger => Rails.logger
# )

# raise "S3_ACCESS_KEY not set" unless ENV['S3_ACCESS_KEY'].present?
config = {
  access_key_id: creds['access_key_id'],
  secret_access_key: creds['secret_access_key'],
  logger: Rails.logger
}
AWS.config(config)
