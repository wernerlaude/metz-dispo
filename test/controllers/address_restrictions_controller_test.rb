require "test_helper"

class AddressRestrictionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @address_restriction = address_restrictions(:one)
  end

  test "should get index" do
    get address_restrictions_url
    assert_response :success
  end

  test "should get new" do
    get new_address_restriction_url
    assert_response :success
  end

  test "should create address_restriction" do
    assert_difference("AddressRestriction.count") do
      post address_restrictions_url, params: { address_restriction: { driver_id: @address_restriction.driver_id, werk_adr_nr: @address_restriction.werk_adr_nr } }
    end

    assert_redirected_to address_restriction_url(AddressRestriction.last)
  end

  test "should show address_restriction" do
    get address_restriction_url(@address_restriction)
    assert_response :success
  end

  test "should get edit" do
    get edit_address_restriction_url(@address_restriction)
    assert_response :success
  end

  test "should update address_restriction" do
    patch address_restriction_url(@address_restriction), params: { address_restriction: { driver_id: @address_restriction.driver_id, werk_adr_nr: @address_restriction.werk_adr_nr } }
    assert_redirected_to address_restriction_url(@address_restriction)
  end

  test "should destroy address_restriction" do
    assert_difference("AddressRestriction.count", -1) do
      delete address_restriction_url(@address_restriction)
    end

    assert_redirected_to address_restrictions_url
  end
end
