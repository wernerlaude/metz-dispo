require "application_system_test_case"

class AddressRestrictionsTest < ApplicationSystemTestCase
  setup do
    @address_restriction = address_restrictions(:one)
  end

  test "visiting the index" do
    visit address_restrictions_url
    assert_selector "h1", text: "Address restrictions"
  end

  test "should create address restriction" do
    visit address_restrictions_url
    click_on "New address restriction"

    fill_in "Driver", with: @address_restriction.driver_id
    fill_in "Werk adr nr", with: @address_restriction.werk_adr_nr
    click_on "Create Address restriction"

    assert_text "Address restriction was successfully created"
    click_on "Back"
  end

  test "should update Address restriction" do
    visit address_restriction_url(@address_restriction)
    click_on "Edit this address restriction", match: :first

    fill_in "Driver", with: @address_restriction.driver_id
    fill_in "Werk adr nr", with: @address_restriction.werk_adr_nr
    click_on "Update Address restriction"

    assert_text "Address restriction was successfully updated"
    click_on "Back"
  end

  test "should destroy Address restriction" do
    visit address_restriction_url(@address_restriction)
    click_on "Destroy this address restriction", match: :first

    assert_text "Address restriction was successfully destroyed"
  end
end
