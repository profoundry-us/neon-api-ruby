# frozen_string_literal: true

RSpec.describe NeonAPI::Object do
  subject(:object) do
    described_class.new(
      "project" => { "id" => "p1", "name" => "Prod" },
      "branches" => [{ "id" => "b1" }, { "id" => "b2" }],
      "active" => true
    )
  end

  it "allows method-style access to top-level keys" do
    expect(object.active).to be(true)
  end

  it "wraps nested hashes" do
    expect(object.project).to be_a(described_class)
    expect(object.project.name).to eq("Prod")
  end

  it "wraps arrays of hashes element-by-element" do
    expect(object.branches).to all(be_a(described_class))
    expect(object.branches.map(&:id)).to eq(%w[b1 b2])
  end

  it "supports hash-style access with strings or symbols" do
    expect(object["project"]["id"]).to eq("p1")
    expect(object[:active]).to be(true)
  end

  it "answers predicate methods for known keys" do
    expect(object.active?).to be(true)
  end

  it "exposes keys and key?" do
    expect(object.keys).to contain_exactly("project", "branches", "active")
    expect(object.key?("project")).to be(true)
    expect(object.key?(:missing)).to be(false)
  end

  it "returns plain data from to_h" do
    expect(object.project.to_h).to eq("id" => "p1", "name" => "Prod")
  end

  it "raises NoMethodError for unknown keys" do
    expect { object.nope }.to raise_error(NoMethodError)
  end

  it "compares by underlying data" do
    expect(object.project).to eq(described_class.new("id" => "p1", "name" => "Prod"))
    expect(object.project).to eq("id" => "p1", "name" => "Prod")
  end

  it "rejects non-hash input" do
    expect { described_class.new([]) }.to raise_error(ArgumentError)
  end
end
