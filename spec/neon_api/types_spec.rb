# frozen_string_literal: true

RSpec.describe NeonAPI::Types do
  describe ".wrap" do
    it "wraps hashes in the given type" do
      wrapped = described_class.wrap({ "id" => "p1" }, NeonAPI::Types::Project)
      expect(wrapped).to be_a(NeonAPI::Types::Project)
    end

    it "wraps arrays element-wise" do
      wrapped = described_class.wrap([{ "id" => "a" }, { "id" => "b" }], NeonAPI::Types::Project)
      expect(wrapped).to all(be_a(NeonAPI::Types::Project))
    end

    it "passes nil and scalars through untouched" do
      expect(described_class.wrap(nil, NeonAPI::Types::Project)).to be_nil
      expect(described_class.wrap("plain", NeonAPI::Types::Project)).to eq("plain")
    end
  end

  describe "generated classes" do
    it "are NeonAPI::Objects with typed readers" do
      project = NeonAPI::Types::Project.new("id" => "p1", "name" => "Prod")
      expect(project).to be_a(NeonAPI::Object)
      expect(project.id).to eq("p1")
      expect(project.name).to eq("Prod")
    end

    it "wraps nested $ref properties in their typed class" do
      response = NeonAPI::Types::ProjectResponse.new("project" => { "id" => "p1" })
      expect(response.project).to be_a(NeonAPI::Types::Project)
      expect(response.project.id).to eq("p1")
    end

    it "wraps array-of-$ref properties element-wise" do
      list = NeonAPI::Types::DatabasesResponse.new("databases" => [{ "name" => "neondb" }])
      expect(list.databases).to all(be_a(NeonAPI::Types::Database))
      expect(list.databases.first.name).to eq("neondb")
    end

    it "merges allOf component schemas into one class (DatabaseOperations)" do
      merged = NeonAPI::Types::DatabaseOperations.new(
        "database" => { "name" => "db" }, "operations" => [{ "id" => "op1" }]
      )
      expect(merged.database).to be_a(NeonAPI::Types::Database)
      expect(merged.operations.first).to be_a(NeonAPI::Types::Operation)
    end

    it "merges inline allOf response composites (ProjectsList)" do
      list = NeonAPI::Types::ProjectsList.new(
        "projects" => [{ "id" => "p1" }], "pagination" => { "cursor" => "c1" }
      )
      expect(list.projects.first).to be_a(NeonAPI::Types::ProjectListItem)
      expect(list.pagination).to be_a(NeonAPI::Types::Pagination)
    end

    it "keeps dynamic access for fields newer than the generated code" do
      project = NeonAPI::Types::Project.new("id" => "p1", "brand_new_field" => 1)
      expect(project.brand_new_field).to eq(1)
      expect(project.id?).to be(true)
      expect(project["id"]).to eq("p1")
      expect(project.to_h).to eq("id" => "p1", "brand_new_field" => 1)
    end

    it "returns nil from typed readers when the field is absent" do
      expect(NeonAPI::Types::ProjectResponse.new({}).project).to be_nil
    end

    it "keeps reserved-word fields reachable via [] (CursorPagination's `next`)" do
      pagination = NeonAPI::Types::CursorPagination.new("next" => "cursor123")
      expect(pagination["next"]).to eq("cursor123")
    end
  end
end
