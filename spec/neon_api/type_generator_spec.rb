# frozen_string_literal: true

require "neon_api/type_generator"

RSpec.describe NeonAPI::TypeGenerator do
  # A miniature OpenAPI document exercising every shape the generator handles:
  # single-$ref responses, component-response refs, inline allOf composites,
  # array responses, $ref'd enum scalars, nested/array refs, and property names
  # that can't (or shouldn't) become Ruby readers.
  let(:spec) do
    {
      "paths" => {
        "/widgets" => {
          "get" => {
            "operationId" => "listWidgets",
            "responses" => { "200" => { "$ref" => "#/components/responses/WidgetList" } }
          },
          "post" => {
            "operationId" => "createWidget",
            "responses" => {
              "201" => {
                "content" => {
                  "application/json" => {
                    "schema" => {
                      "allOf" => [
                        { "$ref" => "#/components/schemas/WidgetResponse" },
                        { "$ref" => "#/components/schemas/PaginationResponse" }
                      ]
                    }
                  }
                }
              }
            }
          }
        },
        "/widgets/{id}" => {
          "get" => {
            "operationId" => "getWidget",
            "responses" => {
              "200" => {
                "content" => {
                  "application/json" => {
                    "schema" => { "$ref" => "#/components/schemas/WidgetResponse" }
                  }
                }
              }
            }
          }
        },
        "/tags" => {
          "get" => {
            "operationId" => "listTags",
            "responses" => {
              "200" => {
                "content" => {
                  "application/json" => {
                    "schema" => { "type" => "array", "items" => { "$ref" => "#/components/schemas/Tag" } }
                  }
                }
              }
            }
          }
        }
      },
      "components" => {
        "responses" => {
          "WidgetList" => {
            "content" => {
              "application/json" => {
                "schema" => { "$ref" => "#/components/schemas/WidgetsResponse" }
              }
            }
          }
        },
        "schemas" => {
          "WidgetsResponse" => {
            "type" => "object",
            "required" => ["widgets"],
            "properties" => {
              "widgets" => { "type" => "array", "items" => { "$ref" => "#/components/schemas/Widget" } }
            }
          },
          "WidgetResponse" => {
            "type" => "object",
            "properties" => { "widget" => { "$ref" => "#/components/schemas/Widget" } }
          },
          "PaginationResponse" => {
            "type" => "object",
            "properties" => { "pagination" => { "type" => "object" } }
          },
          "Widget" => {
            "description" => "A widget.\nLonger prose the generator should drop.",
            "type" => "object",
            "required" => %w[id name],
            "properties" => {
              "id" => { "description" => "The widget ID", "type" => "integer" },
              "name" => { "type" => "string" },
              "state" => { "$ref" => "#/components/schemas/WidgetState" },
              "size" => { "allOf" => [{ "$ref" => "#/components/schemas/WidgetSize" }] },
              "tags" => { "type" => "array", "items" => { "$ref" => "#/components/schemas/Tag" } },
              "keys" => { "type" => "array", "items" => { "type" => "string" } },
              "weird-name" => { "type" => "string" }
            }
          },
          "WidgetState" => { "type" => "string", "enum" => %w[init ready] },
          "WidgetSize" => { "description" => "Widget size in mm", "type" => "integer" },
          "Tag" => {
            "type" => "object",
            "properties" => { "label" => { "type" => "string" } }
          }
        }
      }
    }
  end

  let(:operations) do
    {
      "listWidgets" => nil,
      "getWidget" => nil,
      "createWidget" => "WidgetCreated",
      "listTags" => nil
    }
  end

  let(:source) { described_class.new(spec, operations: operations, source: "spec-fixture").generate }

  it "generates syntactically valid Ruby" do
    expect { RubyVM::InstructionSequence.compile(source) }.not_to raise_error
  end

  it "emits a class per referenced object schema, sorted, under NeonAPI::Types" do
    expect(source).to include("module Types")
    order = %w[Tag Widget WidgetCreated WidgetResponse WidgetsResponse]
    positions = order.map { |name| source.index("class #{name} < NeonAPI::Object") }
    expect(positions).to all(be_a(Integer))
    expect(positions).to eq(positions.sort)
    # Composite parts are inlined into the merged class, not emitted standalone.
    expect(source).not_to include("class PaginationResponse")
  end

  it "synthesizes a merged class for inline allOf composites" do
    expect(source).to include("# WidgetCreated — merged (allOf) response: WidgetResponse + PaginationResponse.")
    widget_created = source[/class WidgetCreated.*?^    end/m]
    expect(widget_created).to include("def widget")
    expect(widget_created).to include("def pagination")
  end

  it "wraps $ref properties (including array items) in their typed class" do
    expect(source).to include('Types.wrap(to_h["widget"], Widget)')
    expect(source).to include('Types.wrap(to_h["tags"], Tag)')
  end

  it "treats $ref'd scalar schemas as scalars, keeping enum and description docs" do
    expect(source).not_to include("class WidgetState")
    expect(source).to include('# One of: "init", "ready".')
    expect(source).to include("# Widget size in mm")
    expect(source).to include('self["state"]')
  end

  it "documents required vs optional properties via YARD" do
    expect(source).to include("# @return [Integer]\n      def id")
    expect(source).to include("# @return [WidgetState, nil]").or include("# @return [String, nil]")
  end

  it "keeps only the first line of descriptions" do
    expect(source).to include("# A widget.")
    expect(source).not_to include("Longer prose")
  end

  it "skips readers that would collide with NeonAPI::Object or aren't valid names" do
    expect(source).not_to match(/def keys\b/)
    expect(source).to include('# NOTE: `keys` collides with a NeonAPI::Object method; read it with obj["keys"].')
    expect(source).not_to include("def weird-name")
    expect(source).to include("# NOTE: `weird-name` is not a valid method name")
  end

  it "records the spec source in the header" do
    expect(source).to include("Source:    spec-fixture")
    expect(source).to include("GENERATED FILE")
  end

  it "raises on an operationId missing from the spec" do
    generator = described_class.new(spec, operations: { "nope" => nil })
    expect { generator.generate }.to raise_error(ArgumentError, /nope/)
  end

  it "raises when a composite response has no class name" do
    generator = described_class.new(spec, operations: { "createWidget" => nil })
    expect { generator.generate }.to raise_error(ArgumentError, /composite response needs a class name/)
  end

  it "raises when a synthetic name collides with a component schema" do
    generator = described_class.new(spec, operations: { "createWidget" => "Widget" })
    expect { generator.generate }.to raise_error(ArgumentError, /collides with a component schema/)
  end
end
