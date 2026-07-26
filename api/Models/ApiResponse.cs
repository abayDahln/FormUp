namespace FormUpAPI.Models
{
    public class ApiResponse<T>
    {
        public string Message { get; set; }
        public int Status { get; set; }

        public T? Data { get; set; }

        public ApiResponse(int responseCode, string message, T? data = default)
        {

            Message = message;
            Status = responseCode;
            Data = data;
        }


    }
}
