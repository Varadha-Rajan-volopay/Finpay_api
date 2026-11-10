module Api
  module V1
    class CategorySerializer
      include Alba::Resource

      attributes :id, :name, :created_at, :updated_at
    end
  end
end
