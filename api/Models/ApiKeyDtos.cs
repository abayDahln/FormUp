using System.ComponentModel.DataAnnotations;

namespace FormUpAPI.Models;

public class RedeemApiKeyRequest
{
    /// <summary>Kode/PW redeem (satu kode per API key).</summary>
    [Required(ErrorMessage = "Kode wajib diisi.")]
    public string Code { get; set; } = null!;
}
