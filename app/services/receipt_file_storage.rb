
# frozen_string_literal: true

class ReceiptFileStorage
  STORAGE_DIRECTORY = Rails.root.join("storage", "tenants")

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    image/jpeg
    image/png
  ].freeze

  MAX_FILE_SIZE = 10.megabytes
  STORAGE_KEY_PATTERN =
  /\A\d+\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|jpeg|png)\z/i

  def initialize(uploaded_file:, tenant_id:)
    @uploaded_file = uploaded_file
    @tenant_id = tenant_id
  end

  def call
    validate_file!

    storage_key = generate_storage_key
    destination = STORAGE_DIRECTORY.join(storage_key)

    FileUtils.mkdir_p(destination.dirname)

    File.open(destination, "wb") do |file|
      file.write(@uploaded_file.read)
    end

    storage_key
  rescue StandardError
    File.delete(destination) if defined?(destination) && destination && File.exist?(destination)
    raise
  end

  def self.delete(storage_key)
    return false unless storage_key.match?(STORAGE_KEY_PATTERN)

    storage_root = STORAGE_DIRECTORY.expand_path
    file_path = storage_root.join(storage_key).expand_path

    return false unless file_path.to_s.start_with?(
      "#{storage_root}#{File::SEPARATOR}"
    )

    return false unless File.file?(file_path)

    File.delete(file_path)
    true
  end

  private

  def validate_file!
    raise ArgumentError, "Receipt file is required" unless @uploaded_file

    unless ALLOWED_CONTENT_TYPES.include?(@uploaded_file.content_type)
      raise ArgumentError, "Only PDF, JPEG and PNG files are allowed"
    end

    if @uploaded_file.size.zero?
      raise ArgumentError, "Receipt file cannot be empty"
    end

    if @uploaded_file.size > MAX_FILE_SIZE
      raise ArgumentError, "Receipt file cannot exceed 10 MB"
    end
  end

  def generate_storage_key
    File.join(
      @tenant_id.to_s,
      "#{SecureRandom.uuid}#{File.extname(@uploaded_file.original_filename).downcase}"
    )
  end
end
