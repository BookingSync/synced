module LosRecordsSyncSetupHelper
  def self.with_multipage_sync_crashing_on_second_page(cassette: "synchronize_los_records")
    VCR.use_cassette(cassette) do
      file_path = File.join(VCR.configuration.cassette_library_dir, "#{cassette}.yml")
      content = YAML.load_file(file_path)
      los_records_from_second_page = JSON.parse(content["http_interactions"].second
                                         .dig("response", "body", "string")).fetch("los_records")
      id_from_the_second_page = los_records_from_second_page.first["id"]

      LosRecord.instance_eval do
        validate do
          # forces to crash on second page
          errors.add(:base, "invalid") if synced_id > id_from_the_second_page
        end
      end

      yield
    end
  end
end
