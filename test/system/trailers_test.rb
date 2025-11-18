require "application_system_test_case"

class TrailersTest < ApplicationSystemTestCase
  setup do
    @trailer = trailers(:one)
  end

  test "visiting the index" do
    visit trailers_url
    assert_selector "h1", text: "Trailers"
  end

  test "should create trailer" do
    visit trailers_url
    click_on "New trailer"

    fill_in "Art", with: @trailer.art
    fill_in "Kennzeichen", with: @trailer.kennzeichen
    click_on "Create Trailer"

    assert_text "Trailer was successfully created"
    click_on "Back"
  end

  test "should update Trailer" do
    visit trailer_url(@trailer)
    click_on "Edit this trailer", match: :first

    fill_in "Art", with: @trailer.art
    fill_in "Kennzeichen", with: @trailer.kennzeichen
    click_on "Update Trailer"

    assert_text "Trailer was successfully updated"
    click_on "Back"
  end

  test "should destroy Trailer" do
    visit trailer_url(@trailer)
    click_on "Destroy this trailer", match: :first

    assert_text "Trailer was successfully destroyed"
  end
end
