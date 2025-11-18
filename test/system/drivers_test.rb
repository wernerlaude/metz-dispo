require "application_system_test_case"

class DriversTest < ApplicationSystemTestCase
  setup do
    @driver = drivers(:one)
  end

  test "visiting the index" do
    visit drivers_url
    assert_selector "h1", text: "Drivers"
  end

  test "should create driver" do
    visit drivers_url
    click_on "New driver"

    check "Active" if @driver.active
    fill_in "Driver type", with: @driver.driver_type
    fill_in "First name", with: @driver.first_name
    fill_in "Last name", with: @driver.last_name
    fill_in "Pin", with: @driver.pin
    fill_in "Tablet", with: @driver.tablet_id
    fill_in "Trailer", with: @driver.trailer_id
    fill_in "Vehicle", with: @driver.vehicle_id
    click_on "Create Driver"

    assert_text "Driver was successfully created"
    click_on "Back"
  end

  test "should update Driver" do
    visit driver_url(@driver)
    click_on "Edit this driver", match: :first

    check "Active" if @driver.active
    fill_in "Driver type", with: @driver.driver_type
    fill_in "First name", with: @driver.first_name
    fill_in "Last name", with: @driver.last_name
    fill_in "Pin", with: @driver.pin
    fill_in "Tablet", with: @driver.tablet_id
    fill_in "Trailer", with: @driver.trailer_id
    fill_in "Vehicle", with: @driver.vehicle_id
    click_on "Update Driver"

    assert_text "Driver was successfully updated"
    click_on "Back"
  end

  test "should destroy Driver" do
    visit driver_url(@driver)
    click_on "Destroy this driver", match: :first

    assert_text "Driver was successfully destroyed"
  end
end
