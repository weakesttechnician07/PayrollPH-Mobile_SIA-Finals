<?php
// ============================================================
// app/Models/AuditLog.php
// ============================================================
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AuditLog extends Model
{
    protected $table      = 'audit_log';
    protected $primaryKey = 'log_id';
    public    $timestamps = false;

    protected $fillable = [
        'user_id','username','action','target','detail','ip_address'
    ];

    protected static function booted()
    {
        static::creating(function ($log) {
            $log->logged_at = now();
        });
    }
}
