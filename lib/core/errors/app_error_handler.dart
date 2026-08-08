import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Class responsible for mapping system exceptions to user-friendly messages
/// and presenting styled error feedback across the app.
class AppErrorHandler {
  AppErrorHandler._();

  /// Map raw exceptions and errors to readable Arabic messages
  static String getUserFriendlyMessage(Object error) {
    final errStr = error.toString();

    // Specific domain errors
    if (errStr.contains('No active shift') || errStr.contains('وردية')) {
      return 'لا توجد وردية مفتوحة حالياً. يرجى فتح وردية جديدة للتمكن من إجراء المعاملات.';
    }
    if (errStr.contains('UNIQUE constraint failed') || errStr.contains('UNIQUE')) {
      return 'البيانات المدخلة مكررة بالفعل (مثل كود المنتج أو اسم العميل). يرجى التغيير والمحاولة مجدداً.';
    }
    if (errStr.contains('FOREIGN KEY constraint failed')) {
      return 'لا يمكن إتمام العملية بسبب ارتباط هذه البيانات بسجلات أخرى في النظام.';
    }
    if (errStr.contains('SqliteException') || errStr.contains('DriftException')) {
      return 'حدث خطأ في قاعدة البيانات أثناء حفظ البيانات. يرجى إعادة المحاولة.';
    }
    if (errStr.contains('SocketException') || errStr.contains('TimeoutException')) {
      return 'تعذر الاتصال بالشبكة. يرجى التأكد من الاتصال بالإنترنت وإعادة المحاولة.';
    }
    if (errStr.contains('FormatException')) {
      return 'صيغة البيانات المدخلة غير صحيحة. يرجى التأكد من الأرقام والحقول.';
    }
    if (errStr.contains('Insufficient stock') || errStr.contains('غير متوفر')) {
      return 'الكمية المطلوبة من المنتج غير متوفرة في المخزن حالياً.';
    }

    // Clean up Exception: prefix if present
    if (errStr.startsWith('Exception: ')) {
      return errStr.replaceFirst('Exception: ', '');
    }

    // Fallback if error string is too long or contains technical stack details
    if (errStr.length > 150 || errStr.contains('\n') || errStr.contains('Stack trace:')) {
      return 'حدث خطأ غير متوقع أثناء معالجة الطلب. يرجى المحاولة لاحقاً.';
    }

    return errStr;
  }

  /// Show a modern styled SnackBar for error messages
  static void showErrorSnackBar(
    BuildContext context,
    Object error, {
    String? customTitle,
  }) {
    if (!context.mounted) return;

    final message = getUserFriendlyMessage(error);
    final rawDetails = error.toString();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.surface,
                  size: 20,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customTitle ?? 'حدث خطأ',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        color: AppColors.surface,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      message,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.sp,
                        color: AppColors.surface.withValues(alpha: 0.95),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (rawDetails != message && rawDetails.length > 30)
                IconButton(
                  icon: Icon(Icons.info_outline, color: AppColors.surface, size: 20),
                  tooltip: 'التفاصيل التقنية',
                  onPressed: () {
                    showErrorDialog(context, error);
                  },
                ),
            ],
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show a success SnackBar
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.surface, size: 22),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show a warning SnackBar
  static void showWarningSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.textPrimary, size: 22),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show an attractive Error Dialog with clean message and expandable technical details
  static Future<void> showErrorDialog(
    BuildContext context,
    Object error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    final userMessage = getUserFriendlyMessage(error);
    final rawDetails = error.toString();

    return showDialog(
      context: context,
      builder: (dialogContext) {
        bool showDetails = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                titlePadding: EdgeInsets.zero,
                contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                title: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          title ?? 'تنبيه خطأ',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 440.w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userMessage,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                          height: 1.5.h,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      InkWell(
                        onTap: () {
                          setState(() {
                            showDetails = !showDetails;
                          });
                        },
                        borderRadius: BorderRadius.circular(6.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          child: Row(
                            children: [
                              Icon(
                                showDetails
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                showDetails ? 'إخفاء التفاصيل التقنية' : 'عرض التفاصيل التقنية',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showDetails) ...[
                        SizedBox(height: 8.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              rawDetails,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(Icons.copy, size: 14),
                            label: Text('نسخ الخطأ', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.sp)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: rawDetails));
                              showSuccessSnackBar(context, 'تم نسخ تفاصيل الخطأ');
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (onRetry != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        onRetry();
                      },
                      icon: Icon(Icons.refresh, size: 18),
                      label: Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('موافق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
