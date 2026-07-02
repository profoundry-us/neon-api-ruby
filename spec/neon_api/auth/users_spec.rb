# frozen_string_literal: true

RSpec.describe NeonAPI::Auth::Users do
  subject(:users) { client.auth("p1", "b1").users }

  let(:base) { "projects/p1/branches/b1/auth/users" }

  describe "#create" do
    it "POSTs email and name (required by the live API) plus password" do
      stub = stub_neon(:post, base,
                       request_body: { email: "ada@example.com", name: "Ada", password: "s3cret" },
                       body: { id: "u1" })
      created = users.create(email: "ada@example.com", name: "Ada", password: "s3cret")
      expect(created).to be_a(NeonAPI::Types::NeonAuthCreateNewUserResponse)
      expect(created.id).to eq("u1")
      expect(stub).to have_been_requested
    end

    it "omits a nil password and forwards extra attributes" do
      stub = stub_neon(:post, base,
                       request_body: { email: "ada@example.com", name: "Ada", role: "admin" },
                       body: {})
      users.create(email: "ada@example.com", name: "Ada", role: "admin")
      expect(stub).to have_been_requested
    end

    it "requires name as a keyword" do
      expect { users.create(email: "ada@example.com") }.to raise_error(ArgumentError, /name/)
    end
  end

  describe "#update" do
    it "PUTs attributes to the user path" do
      stub = stub_neon(:put, "#{base}/u1", request_body: { role: "admin" }, body: { id: "u1" })
      users.update("u1", role: "admin")
      expect(stub).to have_been_requested
    end
  end

  describe "#set_role" do
    it "is a convenience around update" do
      stub = stub_neon(:put, "#{base}/u1", request_body: { role: "editor" }, body: {})
      users.set_role("u1", role: "editor")
      expect(stub).to have_been_requested
    end
  end

  describe "#delete" do
    it "DELETEs the user" do
      stub = stub_neon(:delete, "#{base}/u1", body: {})
      users.delete("u1")
      expect(stub).to have_been_requested
    end
  end
end
