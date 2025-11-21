require "test_helper"

class LoadingLocationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get loading_locations_index_url
    assert_response :success
  end

  test "should get show" do
    get loading_locations_show_url
    assert_response :success
  end

  test "should get new" do
    get loading_locations_new_url
    assert_response :success
  end

  test "should get edit" do
    get loading_locations_edit_url
    assert_response :success
  end
end
